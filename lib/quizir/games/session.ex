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
    answers: %{},
    host_pids: %{},
    host_registered?: false,
    player_pids: %{},
    monitor_refs: %{},
    started_at: nil
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

  def track_host(code_or_pid, pid) do
    call(code_or_pid, {:track_host, pid})
  end

  def untrack_host(code_or_pid, pid) do
    call(code_or_pid, {:untrack_host, pid})
  end

  def track_player(code_or_pid, player_id, pid) do
    call(code_or_pid, {:track_player, player_id, pid})
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

    questions =
      if is_list(quiz.questions) do
        quiz.questions
      else
        []
      end

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
      answers: %{},
      host_pids: %{},
      host_registered?: false,
      player_pids: %{},
      monitor_refs: %{},
      started_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:join_player, name, opts}, _from, %{status: :lobby} = state) do
    clean_name = String.trim(name || "")

    if clean_name == "" do
      {:reply, {:error, :invalid_name}, state}
    else
      existing_entry =
        cond do
          opts[:player_id] && Map.has_key?(state.players, opts[:player_id]) ->
            {opts[:player_id], Map.get(state.players, opts[:player_id])}

          true ->
            Enum.find(state.players, fn {_id, p} ->
              String.downcase(p.name) == String.downcase(clean_name)
            end)
        end

      case existing_entry do
        {existing_id, player} ->
          new_state =
            if pid = opts[:pid] do
              track_player_process(state, existing_id, pid)
            else
              state
            end

          {:reply, {:ok, player}, new_state}

        nil ->
          player_id = generate_player_id()

          player = %{
            id: player_id,
            name: clean_name,
            score: 0,
            streak: 0
          }

          new_players = Map.put(state.players, player_id, player)
          new_state = %{state | players: new_players}

          new_state =
            if pid = opts[:pid] do
              track_player_process(new_state, player_id, pid)
            else
              new_state
            end

          broadcast(new_state, {:player_joined, player})
          {:reply, {:ok, player}, new_state}
      end
    end
  end

  def handle_call({:join_player, name, opts}, _from, state) do
    clean_name = String.trim(name || "")

    existing_entry =
      Enum.find(state.players, fn {_id, p} ->
        String.downcase(p.name) == String.downcase(clean_name)
      end)

    case existing_entry do
      {existing_id, player} ->
        new_state =
          if pid = opts[:pid] do
            track_player_process(state, existing_id, pid)
          else
            state
          end

        {:reply, {:ok, player}, new_state}

      nil ->
        {:reply, {:error, :game_already_started}, state}
    end
  end

  @impl true
  def handle_call({:track_host, pid}, _from, state) do
    new_state = track_host_process(state, pid)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:untrack_host, pid}, _from, state) do
    new_state = untrack_host_process(state, pid)

    if should_terminate_session?(new_state) do
      {:stop, :normal, :ok, new_state}
    else
      {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:track_player, player_id, pid}, _from, state) do
    if Map.has_key?(state.players, player_id) do
      new_state = track_player_process(state, player_id, pid)
      {:reply, :ok, new_state}
    else
      {:reply, {:error, :player_not_found}, state}
    end
  end

  @impl true
  def handle_call({:leave_player, player_id}, _from, state) do
    new_state = do_leave_player(player_id, state)

    if should_terminate_session?(new_state) do
      {:stop, :normal, :ok, new_state}
    else
      {:reply, :ok, new_state}
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
            record_completed_game(new_state, leaderboard)
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

  @impl true
  def handle_info({:DOWN, ref, :process, pid, _reason}, state) do
    case Map.get(state.monitor_refs, ref) do
      {:host, ^pid} ->
        new_state = untrack_host_process(state, pid)

        if should_terminate_session?(new_state) do
          {:stop, :normal, new_state}
        else
          {:noreply, new_state}
        end

      {:player, player_id} ->
        new_state = do_leave_player(player_id, state)

        if should_terminate_session?(new_state) do
          {:stop, :normal, new_state}
        else
          {:noreply, new_state}
        end

      _other ->
        {:noreply, state}
    end
  end

  def handle_info(:tick, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    cancel_timer(state)
    broadcast(state, {:session_terminated, "Cette session a pris fin."})
    :ok
  end

  # --- Internal Helpers ---

  defp track_host_process(state, pid) when is_pid(pid) do
    if Map.has_key?(state.host_pids, pid) do
      %{state | host_registered?: true}
    else
      ref = Process.monitor(pid)

      %{
        state
        | host_pids: Map.put(state.host_pids, pid, ref),
          monitor_refs: Map.put(state.monitor_refs, ref, {:host, pid}),
          host_registered?: true
      }
    end
  end

  defp track_host_process(state, _pid), do: state

  defp untrack_host_process(state, pid) when is_pid(pid) do
    case Map.pop(state.host_pids, pid) do
      {nil, _pids} ->
        state

      {ref, pids} ->
        Process.demonitor(ref, [:flush])
        monitor_refs = Map.delete(state.monitor_refs, ref)
        %{state | host_pids: pids, monitor_refs: monitor_refs}
    end
  end

  defp untrack_host_process(state, _pid), do: state

  defp track_player_process(state, player_id, pid) when is_pid(pid) do
    state =
      case Map.get(state.player_pids, player_id) do
        {old_pid, _old_ref} when old_pid == pid ->
          state

        {_old_pid, old_ref} ->
          Process.demonitor(old_ref, [:flush])

          %{
            state
            | player_pids: Map.delete(state.player_pids, player_id),
              monitor_refs: Map.delete(state.monitor_refs, old_ref)
          }

        nil ->
          state
      end

    if Map.has_key?(state.player_pids, player_id) do
      state
    else
      ref = Process.monitor(pid)

      %{
        state
        | player_pids: Map.put(state.player_pids, player_id, {pid, ref}),
          monitor_refs: Map.put(state.monitor_refs, ref, {:player, player_id})
      }
    end
  end

  defp track_player_process(state, _player_id, _pid), do: state

  defp do_leave_player(player_id, state) do
    if Map.has_key?(state.players, player_id) do
      {player_pids, monitor_refs} =
        case Map.pop(state.player_pids, player_id) do
          {nil, pids} ->
            {pids, state.monitor_refs}

          {{_pid, ref}, pids} ->
            Process.demonitor(ref, [:flush])
            {pids, Map.delete(state.monitor_refs, ref)}
        end

      new_players = Map.delete(state.players, player_id)

      new_state = %{
        state
        | players: new_players,
          player_pids: player_pids,
          monitor_refs: monitor_refs
      }

      broadcast(new_state, {:player_left, player_id})

      maybe_finish_question_early(new_state)
    else
      state
    end
  end

  defp should_terminate_session?(state) do
    state.status == :lobby and
      state.host_registered? and
      map_size(state.host_pids) == 0 and
      map_size(state.players) == 0
  end

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

  defp record_completed_game(state, leaderboard) do
    winner = List.first(leaderboard)
    winner_name = winner && winner.name
    winner_score = (winner && winner.score) || 0
    players_count = map_size(state.players || %{})

    host_user_id =
      cond do
        state.quiz && Ecto.assoc_loaded?(state.quiz.user) && state.quiz.user ->
          state.quiz.user.id

        state.quiz && Map.get(state.quiz, :user_id) ->
          state.quiz.user_id

        true ->
          nil
      end

    attrs = %{
      code: state.code,
      quiz_id: state.quiz && state.quiz.id,
      quiz_title: (state.quiz && state.quiz.title) || "Quiz sans titre",
      host_user_id: host_user_id,
      visibility: to_string(state.visibility),
      players_count: players_count,
      winner_name: winner_name,
      winner_score: winner_score,
      status: "completed",
      started_at: Map.get(state, :started_at),
      finished_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    Quizir.Games.create_game_record(attrs)
  rescue
    _ -> :ok
  end
end
