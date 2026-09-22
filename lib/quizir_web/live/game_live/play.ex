defmodule QuizirWeb.GameLive.Play do
  use QuizirWeb, :live_view

  alias Quizir.Games
  alias Quizir.Games.Session

  @impl true
  def mount(%{"code" => code_param} = params, _session, socket) do
    code = String.upcase(String.trim(code_param))

    case Games.get_game_state(code) do
      {:ok, game_state} ->
        is_host = params["host_token"] != nil and params["host_token"] == game_state.host_token
        host_token = if is_host, do: params["host_token"], else: nil

        player_id = params["player_id"]
        current_player = if player_id, do: Map.get(game_state.players, player_id), else: nil

        if connected?(socket) do
          Phoenix.PubSub.subscribe(Quizir.PubSub, "game:#{code}")

          if is_host do
            Games.track_host(code, self())
          end

          if current_player do
            Games.track_player(code, current_player.id, self())
          end
        end

        join_form =
          if not is_host and current_player == nil do
            to_form(%{"name" => params["name"] || ""})
          else
            nil
          end

        host_join_nickname =
          cond do
            params["name"] && params["name"] != "" -> params["name"]
            socket.assigns[:current_user] -> socket.assigns.current_user.username
            true -> "Hôte"
          end

        bg_music_track = Enum.random([1, 2, 3])

        {:ok,
         socket
         |> assign(:code, code)
         |> assign(:quiz, game_state.quiz)
         |> assign(:visibility, game_state.visibility)
         |> assign(:is_host, is_host)
         |> assign(:host_token, host_token)
         |> assign(:current_player, current_player)
         |> assign(:host_join_nickname, host_join_nickname)
         |> assign(:status, game_state.status)
         |> assign(:questions, game_state.questions)
         |> assign(:current_question_index, game_state.current_question_index)
         |> assign(:time_remaining, game_state.time_remaining)
         |> assign(:players, game_state.players)
         |> assign(:answers, game_state.answers)
         |> assign(:selected_option_id, nil)
         |> assign(:last_answer_result, nil)
         |> assign(:reveal_results, nil)
         |> assign(:leaderboard, Session.build_leaderboard(game_state.players))
         |> assign(:join_form, join_form)
         |> assign(:join_error, nil)
         |> assign(:bg_music_track, bg_music_track)
         |> assign(:page_title, "Partie ##{code}")}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Ce salon de jeu n'existe pas ou la partie est terminée.")
         |> push_navigate(to: ~p"/quizzes")}
    end
  end

  # --- PubSub Handlers ---

  @impl true
  def handle_info({:player_joined, player}, socket) do
    new_players = Map.put(socket.assigns.players, player.id, player)
    leaderboard = Session.build_leaderboard(new_players)

    {:noreply,
     socket
     |> assign(:players, new_players)
     |> assign(:leaderboard, leaderboard)}
  end

  @impl true
  def handle_info({:player_left, player_id}, socket) do
    new_players = Map.delete(socket.assigns.players, player_id)
    leaderboard = Session.build_leaderboard(new_players)

    socket =
      if socket.assigns.current_player && socket.assigns.current_player.id == player_id do
        socket
        |> assign(:current_player, nil)
        |> put_flash(:info, "Vous avez quitté le salon de jeu.")
      else
        socket
      end

    {:noreply,
     socket
     |> assign(:players, new_players)
     |> assign(:leaderboard, leaderboard)}
  end

  @impl true
  def handle_info({:session_terminated, message}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, message)
     |> push_navigate(to: ~p"/games")}
  end

  @impl true
  def handle_info({:game_started, summary}, socket) do
    {:noreply,
     socket
     |> assign(:status, summary.status)
     |> assign(:current_question_index, summary.current_question_index)
     |> assign(:time_remaining, summary.time_remaining)
     |> assign(:selected_option_id, nil)
     |> assign(:last_answer_result, nil)
     |> assign(:reveal_results, nil)
     |> assign(:answers, %{})
     |> push_event("play_sound", %{type: "game_start"})}
  end

  @impl true
  def handle_info({:tick, time_remaining}, socket) do
    {:noreply, assign(socket, :time_remaining, time_remaining)}
  end

  @impl true
  def handle_info({:answer_submitted, %{player_id: player_id}}, socket) do
    new_answers = Map.put(socket.assigns.answers, player_id, true)
    {:noreply, assign(socket, :answers, new_answers)}
  end

  @impl true
  def handle_info({:question_ended, results}, socket) do
    # Mise à jour des scores locaux des joueurs
    {:ok, state} = Games.get_game_state(socket.assigns.code)

    player_id = if socket.assigns.current_player, do: socket.assigns.current_player.id, else: nil
    current_player = if player_id, do: Map.get(state.players, player_id), else: nil
    player_answer = if player_id, do: Map.get(results.answers, player_id), else: nil

    is_correct =
      if player_answer do
        player_answer.is_correct
      else
        nil
      end

    {:noreply,
     socket
     |> assign(:status, :reveal)
     |> assign(:time_remaining, 0)
     |> assign(:reveal_results, results)
     |> assign(:players, state.players)
     |> assign(:current_player, current_player)
     |> assign(:last_answer_result, player_answer)
     |> assign(:leaderboard, results.leaderboard)
     |> push_event("play_sound", %{type: "reveal", is_correct: is_correct})}
  end

  @impl true
  def handle_info({:leaderboard_shown, leaderboard}, socket) do
    {:noreply,
     socket
     |> assign(:status, :leaderboard)
     |> assign(:leaderboard, leaderboard)}
  end

  @impl true
  def handle_info({:question_started, summary}, socket) do
    {:noreply,
     socket
     |> assign(:status, :question)
     |> assign(:current_question_index, summary.current_question_index)
     |> assign(:time_remaining, summary.time_remaining)
     |> assign(:selected_option_id, nil)
     |> assign(:last_answer_result, nil)
     |> assign(:reveal_results, nil)
     |> assign(:answers, %{})}
  end

  @impl true
  def handle_info({:game_finished, leaderboard}, socket) do
    {:noreply,
     socket
     |> assign(:status, :finished)
     |> assign(:leaderboard, leaderboard)
     |> push_event("play_sound", %{type: "game_finished"})}
  end

  # --- User Event Handlers ---

  @impl true
  def handle_event("inline_join", %{"name" => name}, socket) do
    if socket.assigns[:current_player] != nil do
      {:noreply, socket}
    else
      clean_name = String.trim(name || "")

      case Games.join_game(socket.assigns.code, clean_name, pid: self()) do
        {:ok, player} ->
          {:noreply,
           socket
           |> assign(:current_player, player)
           |> assign(:join_form, nil)
           |> assign(:join_error, nil)
           |> put_flash(:info, "Vous avez rejoint la partie !")}

        {:error, :game_already_started} ->
          {:noreply, assign(socket, :join_error, "La partie a déjà commencé.")}

        {:error, :invalid_name} ->
          {:noreply, assign(socket, :join_error, "Veuillez entrer un pseudo valide.")}

        {:error, _} ->
          {:noreply, assign(socket, :join_error, "Impossible de rejoindre ce salon.")}
      end
    end
  end

  @impl true
  def handle_event("host_join", %{"nickname" => nickname}, socket) do
    if socket.assigns[:current_player] != nil do
      {:noreply, socket}
    else
      clean_name = String.trim(nickname || "")

      if clean_name != "" do
        case Games.join_game(socket.assigns.code, clean_name, pid: self()) do
          {:ok, player} ->
            {:noreply,
             socket
             |> assign(:current_player, player)
             |> put_flash(:info, "Vous participez désormais au quiz en tant que joueur !")}

          {:error, :game_already_started} ->
            {:noreply, put_flash(socket, :error, "La partie a déjà commencé.")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Impossible de rejoindre la partie.")}
        end
      else
        {:noreply, put_flash(socket, :error, "Veuillez entrer un pseudo valide.")}
      end
    end
  end

  @impl true
  def handle_event("start_game", _params, socket) do
    if socket.assigns.is_host do
      case Games.start_game(socket.assigns.code, socket.assigns.host_token) do
        :ok ->
          {:noreply, socket}

        {:error, :no_questions} ->
          {:noreply, put_flash(socket, :error, "Ce quiz ne contient aucune question.")}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Erreur lors du démarrage du jeu.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("submit_answer", %{"option_id" => opt_id_str}, socket) do
    option_id = String.to_integer(opt_id_str)

    if socket.assigns.current_player && socket.assigns.status == :question &&
         socket.assigns.selected_option_id == nil do
      case Games.submit_answer(
             socket.assigns.code,
             socket.assigns.current_player.id,
             option_id
           ) do
        {:ok, answer_info} ->
          {:noreply,
           socket
           |> assign(:selected_option_id, option_id)
           |> assign(:last_answer_result, answer_info)
           |> push_event("play_sound", %{type: "click"})}

        {:error, _} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("next_step", _params, socket) do
    if socket.assigns.is_host do
      case Games.next_step(socket.assigns.code, socket.assigns.host_token) do
        :ok -> {:noreply, socket}
        {:error, _} -> {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def terminate(_reason, socket) do
    if socket.assigns[:current_player] do
      Games.leave_game(socket.assigns.code, socket.assigns.current_player.id)
    end

    if socket.assigns[:is_host] do
      Games.untrack_host(socket.assigns.code, self())
    end

    :ok
  end

  # --- Render Template ---

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <!-- Audio Hook & Procedural Audio Engine -->
      <div
        id="game-audio-controller"
        phx-hook="GameAudio"
        data-music-track={@bg_music_track}
        phx-update="ignore"
      >
      </div>

      <div class="max-w-3xl mx-auto py-6">
        <!-- Top status bar -->
        <div class="flex items-center justify-between p-4 mb-6 rounded-2xl bg-base-100 border border-base-300 shadow-sm gap-3 flex-wrap">
          <div class="flex items-center gap-3">
            <span class="text-xs font-bold uppercase tracking-wider text-zinc-400">Salon</span>
            <span
              id="game-code-display"
              class="badge badge-primary font-mono text-lg font-black tracking-widest px-3 py-3"
            >
              {@code}
            </span>
            <span class="text-sm font-semibold truncate max-w-[160px] sm:max-w-xs text-base-content/80">
              {@quiz.title}
            </span>
          </div>

          <div class="flex items-center gap-2 flex-wrap justify-end">
            <!-- Audio Controls Toolbar -->
            <div
              id="game-audio-toolbar"
              class="inline-flex items-center gap-1 bg-base-200/90 px-1.5 py-0.5 rounded-full border border-base-300 text-xs shadow-2xs"
            >
              <button
                type="button"
                id="audio-sfx-toggle"
                class="btn btn-ghost btn-xs px-2 gap-1 rounded-full font-semibold"
                title="Activer/Désactiver les effets sonores (clic, révélation)"
              >
                <span class="sfx-icon hero-speaker-wave size-3.5 text-emerald-500"></span>
                <span class="sfx-text hidden sm:inline">SFX: On</span>
              </button>
              <div class="divider divider-horizontal mx-0 my-0.5"></div>
              <button
                type="button"
                id="audio-music-toggle"
                class="btn btn-ghost btn-xs px-2 gap-1 rounded-full font-semibold"
                title="Activer/Désactiver la musique de fond"
              >
                <span class="music-icon hero-musical-note size-3.5 text-primary"></span>
                <span class="music-text hidden sm:inline">Piste {@bg_music_track}</span>
              </button>
              <button
                type="button"
                id="audio-track-toggle"
                class="btn btn-ghost btn-xs px-1.5 rounded-full"
                title="Changer de musique de fond (3 musiques disponibles)"
              >
                <.icon name="hero-forward" class="size-3 text-base-content/70" />
              </button>
            </div>
            <%= if @is_host do %>
              <span id="host-badge" class="badge badge-neutral text-xs font-semibold gap-1">
                <.icon name="hero-key" class="size-3 text-warning" /> Hôte
              </span>
            <% end %>

            <%= if @current_player do %>
              <div id="player-status-badge" class="badge badge-outline text-xs gap-1 font-semibold">
                <.icon name="hero-user" class="size-3" /> {@current_player.name}
                <span class="badge badge-sm badge-ghost ml-1 font-mono">{@current_player.score} pts</span>
              </div>
            <% end %>

            <%= if @status == :lobby do %>
              <.link
                id="leave-lobby-btn"
                navigate={~p"/games"}
                class="btn btn-ghost btn-xs text-base-content/60 hover:text-error gap-1 ml-1"
                title="Quitter la session"
              >
                <.icon name="hero-arrow-left-on-rectangle" class="size-3.5" />
                <span class="hidden sm:inline">Quitter</span>
              </.link>
            <% end %>
          </div>
        </div>

        <!-- 1. Inline Join Form (if visitor isn't host and hasn't joined) -->
        <%= if @join_form do %>
          <div
            id="inline-join-card"
            class="p-8 rounded-3xl bg-base-100 border border-base-300 shadow-xl max-w-md mx-auto text-center"
          >
            <div class="inline-flex p-3 rounded-2xl bg-primary/10 text-primary mb-3">
              <.icon name="hero-sparkles" class="size-8" />
            </div>
            <h2 class="text-2xl font-bold mb-2">Rejoindre la partie</h2>
            <p class="text-sm text-zinc-500 mb-6">
              Prêt à affronter les autres joueurs ? Entrez votre pseudo !
            </p>

            <div :if={@join_error} id="inline-join-error" class="alert alert-error text-sm mb-4">
              <.icon name="hero-exclamation-circle" class="size-5 shrink-0" />
              <span>{@join_error}</span>
            </div>

            <.form for={@join_form} id="inline-join-form" phx-submit="inline_join" class="space-y-4">
              <.input
                field={@join_form[:name]}
                id="inline-player-name"
                placeholder="Votre pseudo..."
                class="input input-lg w-full text-center font-semibold"
                required
              />

              <.button
                id="inline-join-btn"
                variant="primary"
                class="btn btn-primary btn-lg w-full font-bold"
              >
                C'est parti ! <.icon name="hero-arrow-right" class="size-5 ml-1" />
              </.button>
            </.form>
          </div>
        <% else %>
          <!-- 2. Screen: LOBBY -->
          <%= if @status == :lobby do %>
            <div id="lobby-screen" class="space-y-6">
              <div class="text-center p-8 rounded-3xl bg-base-100 border border-base-300 shadow-sm">
                <div class="flex items-center justify-center gap-2 mb-3">
                  <p class="text-xs uppercase font-bold tracking-widest text-primary">
                    Lobby d'attente
                  </p>
                  <span class={[
                    "badge badge-xs font-semibold gap-1",
                    if(@visibility == "public",
                      do: "badge-success text-white",
                      else: "badge-warning"
                    )
                  ]}>
                    <%= if @visibility == "public" do %>
                      <.icon name="hero-globe-alt" class="size-3" /> Partie Publique
                    <% else %>
                      <.icon name="hero-lock-closed" class="size-3" /> Partie Privée
                    <% end %>
                  </span>
                </div>
                <h1 class="text-4xl font-extrabold mb-3">{@quiz.title}</h1>
                <p class="text-zinc-600 max-w-lg mx-auto text-sm">
                  {@quiz.description || "Préparez vos neurones, la partie va commencer !"}
                </p>

                <div class="mt-6 flex flex-wrap items-center justify-center gap-4">
                  <div class="p-3 px-5 rounded-2xl bg-base-200 border border-base-300 text-center">
                    <span class="text-xs text-zinc-500 block uppercase font-bold">Code PIN</span>
                    <span
                      id="lobby-pin"
                      class="font-mono text-2xl font-black text-primary tracking-widest"
                    >{@code}</span>
                  </div>
                  <div class="p-3 px-5 rounded-2xl bg-base-200 border border-base-300 text-center">
                    <span class="text-xs text-zinc-500 block uppercase font-bold">Questions</span>
                    <span class="font-bold text-2xl">{length(@questions)}</span>
                  </div>
                  <div class="p-3 px-5 rounded-2xl bg-base-200 border border-base-300 text-center">
                    <span class="text-xs text-zinc-500 block uppercase font-bold">Joueurs</span>
                    <span id="players-count" class="font-bold text-2xl text-secondary">{map_size(
                      @players
                    )}</span>
                  </div>
                </div>

                <%= if @is_host do %>
                  <div class="mt-8 flex flex-col items-center gap-4">
                    <.button
                      id="host-start-game-btn"
                      variant="primary"
                      phx-click="start_game"
                      class="btn btn-primary btn-lg px-8 font-bold shadow-lg shadow-primary/30 hover:scale-105 transition"
                    >
                      <.icon name="hero-play" class="size-6 mr-1" /> Démarrer la partie
                    </.button>

                    <%= if @current_player == nil do %>
                      <div
                        id="host-join-card"
                        class="mt-2 p-4 rounded-2xl bg-base-200/80 border border-base-300 max-w-sm w-full text-center"
                      >
                        <p class="text-xs font-semibold text-zinc-500 mb-2">
                          Voulez-vous aussi participer au quiz comme joueur ?
                        </p>
                        <form phx-submit="host_join" class="flex gap-2">
                          <input
                            type="text"
                            name="nickname"
                            id="host-player-name-input"
                            value={@host_join_nickname}
                            placeholder="Votre pseudo de joueur"
                            maxlength="20"
                            required
                            class="input input-sm flex-1 font-semibold"
                          />
                          <.button
                            id="host-join-btn"
                            type="submit"
                            class="btn btn-sm btn-secondary font-bold"
                          >
                            Participer
                          </.button>
                        </form>
                      </div>
                    <% else %>
                      <div
                        id="host-playing-badge"
                        class="badge badge-success badge-sm gap-1 py-3 px-4 font-semibold"
                      >
                        <.icon name="hero-check" class="size-3.5" /> Vous participez en tant que
                        <strong class="ml-1">{@current_player.name}</strong>
                      </div>
                    <% end %>
                  </div>
                <% else %>
                  <div
                    id="player-waiting-notice"
                    class="mt-8 p-4 rounded-2xl bg-base-200 text-sm text-zinc-500 inline-flex items-center gap-2"
                  >
                    <.icon name="hero-arrow-path" class="size-4 animate-spin text-primary" />
                    En attente que l'hôte lance la partie...
                  </div>
                <% end %>
              </div>

              <!-- Players Grid -->
              <div class="p-6 rounded-3xl bg-base-100 border border-base-300 shadow-sm">
                <h3 class="text-lg font-bold mb-4 flex items-center justify-between">
                  <span>Joueurs connectés</span>
                  <span class="badge badge-sm badge-neutral">{map_size(@players)}</span>
                </h3>

                <div id="players-grid" class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
                  <%= if map_size(@players) == 0 do %>
                    <div
                      id="no-players-placeholder"
                      class="col-span-full py-8 text-center text-zinc-400 text-sm"
                    >
                      Aucun joueur pour l'instant. Partagez le code <strong>{@code}</strong> !
                    </div>
                  <% else %>
                    <%= for {_id, player} <- @players do %>
                      <div
                        id={"player-badge-#{player.id}"}
                        class={[
                          "p-3 rounded-2xl border text-center flex items-center justify-center gap-2 font-medium transition",
                          if(@current_player && @current_player.id == player.id,
                            do: "bg-primary/10 border-primary text-primary font-bold shadow-sm",
                            else: "bg-base-200 border-base-300"
                          )
                        ]}
                      >
                        <.icon name="hero-user-circle" class="size-5 shrink-0" />
                        <span class="truncate">{player.name}</span>
                      </div>
                    <% end %>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>

          <!-- 3. Screen: QUESTION -->
          <%= if @status == :question do %>
            <% current_q = Enum.at(@questions, @current_question_index) %>
            <div id="question-screen" class="space-y-6">
              <!-- Timer and Question Progress -->
              <div class="p-6 rounded-3xl bg-base-100 border border-base-300 shadow-sm">
                <div class="flex items-center justify-between mb-4">
                  <span class="badge badge-neutral font-semibold">
                    Question {@current_question_index + 1} / {length(@questions)}
                  </span>

                  <div
                    id="countdown-timer"
                    class={[
                      "flex items-center gap-1.5 px-3 py-1 rounded-full font-mono font-black text-lg",
                      if(@time_remaining <= 5,
                        do: "bg-error text-error-content animate-pulse",
                        else: "bg-base-200 text-base-content"
                      )
                    ]}
                  >
                    <.icon name="hero-clock" class="size-4" />
                    <span>{@time_remaining}s</span>
                  </div>
                </div>

                <h2 id="question-text" class="text-2xl sm:text-3xl font-bold text-center py-6">
                  {current_q.body}
                </h2>

                <!-- Host info on answer submissions -->
                <%= if @is_host do %>
                  <div
                    id="host-answers-progress"
                    class="text-center text-xs text-zinc-400 font-medium pt-2 border-t border-base-200"
                  >
                    {map_size(@answers)} / {max(map_size(@players), 1)} réponse(s) enregistrée(s)
                  </div>
                <% end %>
              </div>

              <!-- Answer Options Grid -->
              <div id="answer-options-grid" class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <%= for {option, idx} <- Enum.with_index(current_q.answer_options) do %>
                  <% color_classes =
                    case rem(idx, 4) do
                      0 -> "bg-rose-500 hover:bg-rose-600 text-white border-rose-600"
                      1 -> "bg-blue-500 hover:bg-blue-600 text-white border-blue-600"
                      2 -> "bg-amber-500 hover:bg-amber-600 text-white border-amber-600"
                      3 -> "bg-emerald-500 hover:bg-emerald-600 text-white border-emerald-600"
                    end %>

                  <button
                    type="button"
                    id={"answer-option-btn-#{option.id}"}
                    phx-click="submit_answer"
                    phx-value-option_id={option.id}
                    disabled={@selected_option_id != nil or not is_map(@current_player)}
                    class={[
                      "p-6 rounded-2xl border-2 font-bold text-lg text-left transition transform active:scale-95 shadow-md flex items-center justify-between",
                      color_classes,
                      @selected_option_id == option.id &&
                        "ring-4 ring-offset-2 ring-white scale-[1.02]",
                      @selected_option_id != nil && @selected_option_id != option.id &&
                        "opacity-40 grayscale-[30%]"
                    ]}
                  >
                    <span>{option.body}</span>
                    <span class="size-8 rounded-full bg-white/20 flex items-center justify-center font-bold text-sm shrink-0">
                      {["A", "B", "C", "D"] |> Enum.at(rem(idx, 4))}
                    </span>
                  </button>
                <% end %>
              </div>

              <%= if @selected_option_id != nil do %>
                <div
                  id="answer-submitted-banner"
                  class="alert alert-info text-center py-3 text-sm font-medium"
                >
                  <.icon name="hero-check-circle" class="size-5 shrink-0" />
                  Réponse enregistrée ! En attente de la fin du compte à rebours...
                </div>
              <% end %>
            </div>
          <% end %>

          <!-- 4. Screen: REVEAL (after question times out or everyone answered) -->
          <%= if @status == :reveal do %>
            <% current_q = Enum.at(@questions, @current_question_index) %>
            <div id="reveal-screen" class="space-y-6">
              <div class="p-6 rounded-3xl bg-base-100 border border-base-300 shadow-sm text-center">
                <span class="badge badge-neutral text-xs mb-2">Question {@current_question_index + 1} terminée</span>
                <h2 class="text-2xl font-bold mb-4">{current_q.body}</h2>

                <%= if @current_player do %>
                  <%= if @last_answer_result && @last_answer_result.is_correct do %>
                    <div
                      id="player-correct-banner"
                      class="alert alert-success max-w-sm mx-auto my-4 py-3 font-bold text-center justify-center"
                    >
                      <.icon name="hero-check-circle" class="size-6" />
                      Bien joué ! +{@last_answer_result.points} pts
                    </div>
                  <% else %>
                    <div
                      id="player-wrong-banner"
                      class="alert alert-error max-w-sm mx-auto my-4 py-3 font-bold text-center justify-center"
                    >
                      <.icon name="hero-x-circle" class="size-6" /> Raté ! (0 point)
                    </div>
                  <% end %>
                <% end %>

                <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 mt-6">
                  <%= for option <- current_q.answer_options do %>
                    <div
                      id={"reveal-option-#{option.id}"}
                      class={[
                        "p-4 rounded-xl border text-sm font-semibold flex items-center justify-between",
                        if(option.is_correct,
                          do: "bg-success/20 border-success text-success font-bold text-base",
                          else: "bg-base-200 border-base-300 text-base-content/40 line-through"
                        )
                      ]}
                    >
                      <span>{option.body}</span>
                      <%= if option.is_correct do %>
                        <span class="badge badge-success badge-sm gap-1">
                          <.icon name="hero-check" class="size-3" /> Correct
                        </span>
                      <% end %>
                    </div>
                  <% end %>
                </div>

                <%= if @is_host do %>
                  <div class="mt-8">
                    <.button
                      id="host-show-leaderboard-btn"
                      variant="primary"
                      phx-click="next_step"
                      class="btn btn-primary font-bold px-6"
                    >
                      Afficher le classement <.icon name="hero-arrow-right" class="size-4 ml-1" />
                    </.button>
                  </div>
                <% else %>
                  <p class="text-xs text-zinc-400 mt-6">L'hôte va afficher le classement...</p>
                <% end %>
              </div>
            </div>
          <% end %>

          <!-- 5. Screen: LEADERBOARD -->
          <%= if @status == :leaderboard do %>
            <div id="leaderboard-screen" class="space-y-6">
              <div class="p-8 rounded-3xl bg-base-100 border border-base-300 shadow-sm text-center">
                <p class="text-xs uppercase font-bold tracking-widest text-primary mb-1">
                  Classement
                </p>
                <h2 class="text-3xl font-extrabold mb-6">Tableau des scores</h2>

                <div id="leaderboard-list" class="space-y-3 max-w-lg mx-auto">
                  <%= for player <- @leaderboard do %>
                    <div
                      id={"leaderboard-player-#{player.id}"}
                      class={[
                        "p-4 rounded-2xl border flex items-center justify-between transition",
                        case player.rank do
                          1 -> "bg-amber-100/70 border-amber-300 text-amber-900 font-bold"
                          2 -> "bg-slate-200/70 border-slate-300 text-slate-800 font-semibold"
                          3 -> "bg-orange-100/70 border-orange-300 text-orange-900 font-semibold"
                          _ -> "bg-base-200 border-base-300"
                        end
                      ]}
                    >
                      <div class="flex items-center gap-3">
                        <span class="size-7 rounded-full bg-base-100 flex items-center justify-center text-xs font-black shadow-xs">
                          #{player.rank}
                        </span>
                        <span class="font-bold">{player.name}</span>
                        <%= if player.streak >= 2 do %>
                          <span class="badge badge-warning badge-xs gap-1">
                            🔥 {player.streak}
                          </span>
                        <% end %>
                      </div>

                      <span class="font-mono font-bold text-lg">{player.score} pts</span>
                    </div>
                  <% end %>
                </div>

                <%= if @is_host do %>
                  <div class="mt-8">
                    <.button
                      id="host-next-question-btn"
                      variant="primary"
                      phx-click="next_step"
                      class="btn btn-primary font-bold px-6"
                    >
                      <%= if @current_question_index + 1 < length(@questions) do %>
                        Question suivante <.icon name="hero-arrow-right" class="size-4 ml-1" />
                      <% else %>
                        Podium final <.icon name="hero-trophy" class="size-4 ml-1" />
                      <% end %>
                    </.button>
                  </div>
                <% else %>
                  <p class="text-xs text-zinc-400 mt-6">En attente de l'hôte pour la suite...</p>
                <% end %>
              </div>
            </div>
          <% end %>

          <!-- 6. Screen: FINISHED -->
          <%= if @status == :finished do %>
            <div id="finished-screen" class="space-y-6 text-center">
              <div class="p-8 sm:p-12 rounded-3xl bg-base-100 border border-base-300 shadow-xl">
                <div class="inline-flex p-4 rounded-3xl bg-warning/20 text-warning mb-4 animate-bounce">
                  <.icon name="hero-trophy" class="size-12" />
                </div>
                <h1 class="text-4xl font-black mb-2">Partie terminée !</h1>
                <p class="text-zinc-500 text-sm mb-8">Félicitations à tous les participants !</p>

                <!-- Podium Top 3 -->
                <div
                  id="podium"
                  class="flex items-end justify-center gap-3 sm:gap-6 mb-10 max-w-md mx-auto"
                >
                  <% top_3 = Enum.take(@leaderboard, 3) %>

                  <!-- 2nd place -->
                  <%= if second = Enum.at(top_3, 1) do %>
                    <div id="podium-2nd" class="flex-1 text-center">
                      <div class="font-bold text-sm truncate mb-1">{second.name}</div>
                      <div class="p-3 pt-6 rounded-t-2xl bg-slate-300 border border-slate-400 h-28 flex flex-col justify-between">
                        <span class="font-black text-2xl text-slate-800">2</span>
                        <span class="text-xs font-mono font-semibold">{second.score} pts</span>
                      </div>
                    </div>
                  <% end %>

                  <!-- 1st place -->
                  <%= if first = Enum.at(top_3, 0) do %>
                    <div id="podium-1st" class="flex-1 text-center -mt-6">
                      <div class="text-warning text-xs uppercase font-black tracking-wider mb-1">
                        👑 Vainqueur
                      </div>
                      <div class="font-extrabold text-base truncate mb-1">{first.name}</div>
                      <div class="p-4 pt-8 rounded-t-2xl bg-amber-300 border-2 border-amber-400 h-36 flex flex-col justify-between shadow-lg">
                        <span class="font-black text-4xl text-amber-900">1</span>
                        <span class="text-sm font-mono font-bold text-amber-900">{first.score} pts</span>
                      </div>
                    </div>
                  <% end %>

                  <!-- 3rd place -->
                  <%= if third = Enum.at(top_3, 2) do %>
                    <div id="podium-3rd" class="flex-1 text-center">
                      <div class="font-bold text-sm truncate mb-1">{third.name}</div>
                      <div class="p-3 pt-4 rounded-t-2xl bg-orange-200 border border-orange-300 h-20 flex flex-col justify-between">
                        <span class="font-black text-xl text-orange-900">3</span>
                        <span class="text-xs font-mono font-semibold">{third.score} pts</span>
                      </div>
                    </div>
                  <% end %>
                </div>

                <div>
                  <.button id="return-quizzes-btn" navigate={~p"/quizzes"} class="btn btn-outline">
                    <.icon name="hero-arrow-left" class="size-4 mr-1" /> Retourner aux quiz
                  </.button>
                </div>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
