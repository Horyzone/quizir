defmodule Quizir.Games.Session do
  @moduledoc """
  GenServer représentant une session de jeu multijoueur Quizir.
  Gère les joueurs, les transitions d'état, les chronomètres et la diffusion PubSub.
  """

  use GenServer, restart: :transient

  alias Quizir.Games.Session

  @enforce_keys [:code, :host_token, :quiz]
  defstruct [
    :code,
    :host_token,
    :quiz,
    visibility: "public",
    status: :lobby,
    questions: [],
    current_question_index: 0,
    time_remaining: 0,
    timer_ref: nil,
    timer_interval: 1000,
    pubsub: Quizir.PubSub,
    players: %{},
    answers: %{}
  ]

  # --- Client API ---

  def start_link(opts) do
    code = Keyword.fetch!(opts, :code)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(code))
  end

  def via_tuple(code) do
    {:via, Registry, {Quizir.Games.SessionRegistry, code}}
  end

  def get_state(code_or_pid) do
    call(code_or_pid, :get_state)
  end

  def join_player(code_or_pid, name, opts \\ []) do
    call(code_or_pid, {:join_player, name, opts})
  end

  def leave_player(code_or_pid, player_id) do
    call(code_or_pid, {:leave_player, player_id})
  end

  def start_game(code_or_pid, host_token) do
    call(code_or_pid, {:start_game, host_token})
  end

  def submit_answer(code_or_pid, player_id, option_id) do
    call(code_or_pid, {:submit_answer, player_id, option_id})
  end

  def next_step(code_or_pid, host_token) do
    call(code_or_pid, {:next_step, host_token})
  end

  def stop(code_or_pid) do
    GenServer.stop(resolve_target(code_or_pid))
  end

  defp call(code_or_pid, msg) do
    GenServer.call(resolve_target(code_or_pid), msg)
  end

  defp resolve_target(pid) when is_pid(pid), do: pid
  defp resolve_target(code) when is_binary(code), do: via_tuple(code)

  # --- GenServer Callbacks ---

  @impl true
  def init(opts) do
    code = Keyword.fetch!(opts, :code)
    host_token = Keyword.fetch!(opts, :host_token)
    quiz = Keyword.fetch!(opts, :quiz)
    pubsub = Keyword.get(opts, :pubsub, Quizir.PubSub)
    timer_interval = Keyword.get(opts, :timer_interval, 1000)
    raw_visibility = Keyword.get(opts, :visibility, "public")

    visibility =
      if to_string(raw_visibility) in ["public", "private"],
        do: to_string(raw_visibility),
        else: "public"

    questions = quiz.questions || []

    state = %Session{
      code: code,
      host_token: host_token,
      quiz: quiz,
      visibility: visibility,
      status: :lobby,
      questions: questions,
      current_question_index: 0,
      time_remaining: 0,
      timer_interval: timer_interval,
      pubsub: pubsub,
      players: %{},
      answers: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:join_player, name, _opts}, _from, %{status: :lobby} = state) do
    clean_name = String.trim(name || "")

    cond do
      clean_name == "" ->
        {:reply, {:error, :invalid_name}, state}

      true ->
        player_id = generate_player_id()

        player = %{
          id: player_id,
          name: clean_name,
          score: 0,
          streak: 0
        }

        new_players = Map.put(state.players, player_id, player)
        new_state = %{state | players: new_players}

        broadcast(new_state, {:player_joined, player})
        {:reply, {:ok, player}, new_state}
    end
  end

  def handle_call({:join_player, _name, _opts}, _from, state) do
    {:reply, {:error, :game_already_started}, state}
  end

  @impl true
  def handle_call({:leave_player, player_id}, _from, state) do
    if Map.has_key?(state.players, player_id) do
      new_players = Map.delete(state.players, player_id)
      new_state = %{state | players: new_players}

      broadcast(new_state, {:player_left, player_id})

      # Si on est en cours de question et que tous les joueurs restants ont répondu
      new_state = maybe_finish_question_early(new_state)
      {:reply, :ok, new_state}
    else
      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:start_game, host_token}, _from, %{status: :lobby} = state) do
    cond do
      host_token != state.host_token ->
        {:reply, {:error, :unauthorized}, state}

      Enum.empty?(state.questions) ->
        {:reply, {:error, :no_questions}, state}

      true ->
        current_q = Enum.at(state.questions, 0)
        time_limit = current_q.time_limit_seconds || 20

        timer_ref = schedule_tick(state.timer_interval)

        new_state = %{
          state
          | status: :question,
            current_question_index: 0,
            time_remaining: time_limit,
            timer_ref: timer_ref,
            answers: %{}
        }

        broadcast(new_state, {:game_started, sanitize_state_for_broadcast(new_state)})
        {:reply, :ok, new_state}
    end
  end

  def handle_call({:start_game, _host_token}, _from, state) do
    {:reply, {:error, :invalid_state}, state}
  end

  @impl true
  def handle_call({:submit_answer, player_id, option_id}, _from, %{status: :question} = state) do
    cond do
      not Map.has_key?(state.players, player_id) ->
        {:reply, {:error, :not_a_player}, state}

      Map.has_key?(state.answers, player_id) ->
        {:reply, {:error, :already_answered}, state}

      true ->
        current_q = Enum.at(state.questions, state.current_question_index)
        option = Enum.find(current_q.answer_options || [], fn opt -> opt.id == option_id end)
        player = Map.fetch!(state.players, player_id)

        is_correct = option != nil and option.is_correct == true

        {points, new_streak} =
          if is_correct do
            streak = player.streak
            speed_ratio = state.time_remaining / max(current_q.time_limit_seconds || 20, 1)
            speed_points = round(500 + 500 * speed_ratio)
            streak_bonus = min(streak * 100, 500)
            {speed_points + streak_bonus, streak + 1}
          else
            {0, 0}
          end

        answer_record = %{
          option_id: option_id,
          is_correct: is_correct,
          points: points,
          time_remaining: state.time_remaining
        }

        updated_player = %{
          player
          | score: player.score + points,
            streak: new_streak
        }

        new_players = Map.put(state.players, player_id, updated_player)
        new_answers = Map.put(state.answers, player_id, answer_record)

        new_state = %{state | players: new_players, answers: new_answers}

        broadcast(new_state, {
          :answer_submitted,
          %{
            player_id: player_id,
            answers_count: map_size(new_answers),
            total_players: map_size(new_players)
          }
        })

        new_state = maybe_finish_question_early(new_state)
        {:reply, {:ok, answer_record}, new_state}
    end
  end

  def handle_call({:submit_answer, _player_id, _option_id}, _from, state) do
    {:reply, {:error, :not_in_question_state}, state}
  end

  @impl true
  def handle_call({:next_step, host_token}, _from, state) do
    if host_token != state.host_token do
      {:reply, {:error, :unauthorized}, state}
    else
      case state.status do
        :reveal ->
          leaderboard = build_leaderboard(state.players)
          new_state = %{state | status: :leaderboard}
          broadcast(new_state, {:leaderboard_shown, leaderboard})
          {:reply, :ok, new_state}

        :leaderboard ->
          next_index = state.current_question_index + 1

          if next_index < length(state.questions) do
            next_q = Enum.at(state.questions, next_index)
            time_limit = next_q.time_limit_seconds || 20
            timer_ref = schedule_tick(state.timer_interval)

            new_state = %{
              state
              | status: :question,
                current_question_index: next_index,
                time_remaining: time_limit,
                timer_ref: timer_ref,
                answers: %{}
            }

            broadcast(new_state, {:question_started, sanitize_state_for_broadcast(new_state)})
            {:reply, :ok, new_state}
          else
            new_state = %{state | status: :finished}
            leaderboard = build_leaderboard(state.players)
            broadcast(new_state, {:game_finished, leaderboard})
            {:reply, :ok, new_state}
          end

        _other ->
          {:reply, {:error, :invalid_state}, state}
      end
    end
  end

  @impl true
  def handle_info(:tick, %{status: :question} = state) do
    if state.time_remaining > 1 do
      new_time = state.time_remaining - 1
      timer_ref = schedule_tick(state.timer_interval)
      new_state = %{state | time_remaining: new_time, timer_ref: timer_ref}

      broadcast(new_state, {:tick, new_time})
      {:noreply, new_state}
    else
      new_state = finish_question(state)
      {:noreply, new_state}
    end
  end

  def handle_info(:tick, state) do
    {:noreply, state}
  end

  # --- Internal Helpers ---

  defp schedule_tick(interval) do
    Process.send_after(self(), :tick, interval)
  end

  defp cancel_timer(%{timer_ref: ref}) when is_reference(ref) do
    Process.cancel_timer(ref)
  end

  defp cancel_timer(_), do: :ok

  defp maybe_finish_question_early(%{status: :question} = state) do
    total_players = map_size(state.players)

    if total_players > 0 and map_size(state.answers) >= total_players do
      cancel_timer(state)
      finish_question(state)
    else
      state
    end
  end

  defp maybe_finish_question_early(state), do: state

  defp finish_question(state) do
    cancel_timer(state)
    current_q = Enum.at(state.questions, state.current_question_index)

    correct_options =
      (current_q.answer_options || [])
      |> Enum.filter(&(&1.is_correct == true))
      |> Enum.map(& &1.id)

    results = %{
      question_id: current_q.id,
      correct_option_ids: correct_options,
      answers: state.answers,
      leaderboard: build_leaderboard(state.players)
    }

    new_state = %{state | status: :reveal, timer_ref: nil, time_remaining: 0}
    broadcast(new_state, {:question_ended, results})
    new_state
  end

  def build_leaderboard(players) do
    players
    |> Map.values()
    |> Enum.sort_by(& &1.score, :desc)
    |> Enum.with_index(1)
    |> Enum.map(fn {player, rank} ->
      Map.put(player, :rank, rank)
    end)
  end

  defp broadcast(state, message) do
    Phoenix.PubSub.broadcast(state.pubsub, "game:#{state.code}", message)
  end

  defp sanitize_state_for_broadcast(state) do
    current_q = Enum.at(state.questions, state.current_question_index)

    sanitized_question =
      if current_q do
        options =
          Enum.map(current_q.answer_options || [], fn opt ->
            %{id: opt.id, body: opt.body}
          end)

        %{
          id: current_q.id,
          order: current_q.order,
          body: current_q.body,
          time_limit_seconds: current_q.time_limit_seconds,
          answer_options: options
        }
      else
        nil
      end

    %{
      status: state.status,
      current_question_index: state.current_question_index,
      total_questions: length(state.questions),
      time_remaining: state.time_remaining,
      current_question: sanitized_question,
      answers_count: map_size(state.answers),
      total_players: map_size(state.players)
    }
  end

  defp generate_player_id do
    "ply_" <> (:crypto.strong_rand_bytes(6) |> Base.url_encode64(padding: false))
  end
end
