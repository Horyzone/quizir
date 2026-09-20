defmodule Quizir.Games do
  @moduledoc """
  Contexte métier pour le moteur de jeu multijoueur en temps réel.
  Gère le cycle de vie des sessions via SessionSupervisor et SessionRegistry.
  """

  alias Quizir.Games.Session
  alias Quizir.Games.SessionRegistry
  alias Quizir.Games.SessionSupervisor

  @alphabet ~c"23456789ABCDEFGHJKLMNPQRSTUVWXYZ"

  @doc """
  Crée une nouvelle partie multijoueur pour un quiz donné.
  Retourne `{:ok, %{code: code, host_token: host_token, pid: pid}}`.
  """
  def create_game(quiz, opts \\ []) do
    code = opts[:code] || generate_unique_code()
    host_token = opts[:host_token] || generate_token()
    raw_visibility = Keyword.get(opts, :visibility, "public")

    visibility =
      if to_string(raw_visibility) in ["public", "private"],
        do: to_string(raw_visibility),
        else: "public"

    session_opts =
      [
        code: code,
        host_token: host_token,
        quiz: quiz,
        visibility: visibility
      ] ++ Keyword.drop(opts, [:code, :host_token, :visibility])

    child_spec = {Session, session_opts}

    case DynamicSupervisor.start_child(SessionSupervisor, child_spec) do
      {:ok, pid} ->
        {:ok, %{code: code, host_token: host_token, pid: pid, visibility: visibility}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Retourne la liste des sessions de jeu publiques actives.
  """
  def list_active_public_games do
    Registry.select(SessionRegistry, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.map(fn {_code, pid} ->
      try do
        Session.get_state(pid)
      catch
        :exit, _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(fn state ->
      to_string(state.visibility) == "public" and
        state.status in [:lobby, :question, :reveal, :leaderboard]
    end)
    |> Enum.sort_by(fn state -> length(Map.keys(state.players || %{})) end, :desc)
  end

  @doc """
  Vérifie si une session de jeu est active pour le code donné.
  """
  def game_exists?(code) when is_binary(code) do
    case Registry.lookup(SessionRegistry, code) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  @doc """
  Récupère l'état complet d'une session de jeu.
  Retourne `{:ok, state}` ou `{:error, :not_found}`.
  """
  def get_game_state(code) when is_binary(code) do
    if game_exists?(code) do
      {:ok, Session.get_state(code)}
    else
      {:error, :not_found}
    end
  catch
    :exit, _ -> {:error, :not_found}
  end

  @doc """
  Permet à un joueur de rejoindre le salon.
  """
  def join_game(code, name, opts \\ []) do
    if game_exists?(code) do
      Session.join_player(code, name, opts)
    else
      {:error, :not_found}
    end
  catch
    :exit, _ -> {:error, :not_found}
  end

  @doc """
  Retire un joueur du salon.
  """
  def leave_game(code, player_id) do
    if game_exists?(code) do
      Session.leave_player(code, player_id)
    else
      :ok
    end
  catch
    :exit, _ -> :ok
  end

  @doc """
  Démarre la partie depuis le salon (réservé à l'hôte).
  """
  def start_game(code, host_token) do
    if game_exists?(code) do
      Session.start_game(code, host_token)
    else
      {:error, :not_found}
    end
  catch
    :exit, _ -> {:error, :not_found}
  end

  @doc """
  Soumet une réponse pour un joueur à la question courante.
  """
  def submit_answer(code, player_id, option_id) do
    if game_exists?(code) do
      Session.submit_answer(code, player_id, option_id)
    else
      {:error, :not_found}
    end
  catch
    :exit, _ -> {:error, :not_found}
  end

  @doc """
  Passe à l'étape suivante (reveal -> leaderboard -> question suivante ou fin).
  """
  def next_step(code, host_token) do
    if game_exists?(code) do
      Session.next_step(code, host_token)
    else
      {:error, :not_found}
    end
  catch
    :exit, _ -> {:error, :not_found}
  end

  @doc """
  Génère un code de salon aléatoire (6 caractères lisibles).
  """
  def generate_code do
    Enum.take_random(@alphabet, 6) |> to_string()
  end

  defp generate_unique_code do
    code = generate_code()

    if game_exists?(code) do
      generate_unique_code()
    else
      code
    end
  end

  @doc """
  Génère un token secret aléatoire pour l'hôte.
  """
  def generate_token do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end
end
