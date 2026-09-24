defmodule QuizirWeb.GameLive.Index do
  use QuizirWeb, :live_view

  alias Quizir.Games

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Rafraîchissement périodique léger des parties en cours
      :timer.send_interval(3000, self(), :refresh_games)
    end

    games = Games.list_active_public_games()

    nickname =
      if socket.assigns[:current_user] do
        socket.assigns.current_user.username
      else
        ""
      end

    socket =
      socket
      |> assign(:page_title, "Parties en cours")
      |> assign(:nickname, nickname)
      |> assign(:join_modal_game, nil)
      |> assign(:nickname_error, nil)
      |> stream_configure(:games, dom_id: &"games-#{&1.code}")
      |> stream(:games, games)

    {:ok, socket}
  end

  @impl true
  def handle_info(:refresh_games, socket) do
    games = Games.list_active_public_games()
    {:noreply, stream(socket, :games, games, reset: true)}
  end

  @impl true
  def handle_event("click_join", %{"code" => code}, socket) do
    user = socket.assigns[:current_user]

    if user do
      # Utilisateur connecté : pas besoin de code PIN ni de demander son pseudo
      case Games.join_game(code, user.username) do
        {:ok, player} ->
          {:noreply,
           socket
           |> put_flash(:info, "Vous avez rejoint la partie !")
           |> push_navigate(
             to: ~p"/games/#{code}?player_id=#{player.id}&name=#{URI.encode(player.name)}"
           )}

        {:error, :game_already_started} ->
          {:noreply, put_flash(socket, :error, "Cette partie a déjà commencé.")}

        {:error, _} ->
          {:noreply, push_navigate(socket, to: ~p"/games/#{code}")}
      end
    else
      # Utilisateur anonyme : ouvrir le modal pour demander son pseudo
      case Games.get_game_state(code) do
        {:ok, state} ->
          {:noreply, assign(socket, join_modal_game: state, nickname_error: nil)}

        {:error, _} ->
          {:noreply,
           socket
           |> put_flash(:error, "Cette partie n'est plus disponible.")
           |> stream(:games, Games.list_active_public_games(), reset: true)}
      end
    end
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, join_modal_game: nil, nickname_error: nil)}
  end

  @impl true
  def handle_event("submit_guest_join", %{"nickname" => nickname, "code" => code}, socket) do
    clean_name = String.trim(nickname || "")

    if clean_name == "" do
      {:noreply, assign(socket, :nickname_error, "Veuillez entrer un pseudo.")}
    else
      case Games.join_game(code, clean_name) do
        {:ok, player} ->
          {:noreply,
           socket
           |> put_flash(:info, "Bienvenue #{player.name} dans la partie !")
           |> push_navigate(
             to: ~p"/games/#{code}?player_id=#{player.id}&name=#{URI.encode(player.name)}"
           )}

        {:error, :game_already_started} ->
          {:noreply, assign(socket, :nickname_error, "La partie a déjà commencé.")}

        {:error, :invalid_name} ->
          {:noreply, assign(socket, :nickname_error, "Pseudo invalide.")}

        {:error, _} ->
          {:noreply, assign(socket, :nickname_error, "Impossible de rejoindre cette partie.")}
      end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-5xl mx-auto py-8 px-4 sm:px-6">
        <!-- 1. En-tête -->
        <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 mb-8">
          <div>
            <div class="flex items-center gap-3">
              <div class="p-2.5 rounded-2xl bg-emerald-500/10 text-emerald-600">
                <.icon name="hero-globe-alt" class="size-6" />
              </div>
              <h1 class="text-3xl font-black tracking-tight text-base-content">
                Parties en cours
              </h1>
            </div>
            <p class="text-sm text-base-content/60 mt-1">
              Rejoignez une session publique ouverte à tous en un clic, sans avoir besoin de code PIN !
            </p>
          </div>

          <div class="flex flex-col sm:flex-row items-stretch sm:items-center gap-3 w-full sm:w-auto shrink-0">
            <.link
              navigate={~p"/join"}
              id="join-private-btn"
              class="btn btn-outline font-bold gap-2 px-5 py-2.5 h-auto min-h-11 whitespace-nowrap justify-center text-sm shadow-xs hover:border-amber-500 hover:bg-amber-500/10 hover:text-amber-600 transition-all"
            >
              <.icon name="hero-lock-closed" class="size-4 text-amber-500 shrink-0" />
              <span>Rejoindre avec un PIN</span>
            </.link>
            <.link
              navigate={~p"/quizzes"}
              id="launch-own-game-btn"
              class="btn btn-primary font-bold gap-2 px-5 py-2.5 h-auto min-h-11 whitespace-nowrap justify-center text-sm shadow-md hover:shadow-lg transition-all"
            >
              <.icon name="hero-play" class="size-4 shrink-0" />
              <span>Lancer un quiz</span>
            </.link>
          </div>
        </div>

        <!-- 2. Grille des parties publiques actives -->
        <div id="active-games-list" phx-update="stream" class="grid grid-cols-1 md:grid-cols-2 gap-5">
          <div
            id="empty-games-state"
            class="hidden only:block text-center py-16 px-4 col-span-1 md:col-span-2 bg-base-100 border border-dashed border-base-300 rounded-3xl"
          >
            <div class="size-16 rounded-2xl bg-emerald-500/10 text-emerald-600 mx-auto flex items-center justify-center mb-4">
              <.icon name="hero-puzzle-piece" class="size-8" />
            </div>
            <h3 class="text-xl font-bold text-base-content mb-1">
              Aucune partie publique en attente
            </h3>
            <p class="text-sm text-base-content/60 max-w-md mx-auto mb-6">
              Soyez le premier à lancer une session ouverte à toute la communauté ou rejoignez un salon privé avec son code PIN.
            </p>
            <div class="flex flex-col sm:flex-row items-center justify-center gap-3">
              <.link
                navigate={~p"/quizzes"}
                class="btn btn-primary btn-sm font-bold gap-2 w-full sm:w-auto"
              >
                <.icon name="hero-play" class="size-4" /> Lancer une partie publique
              </.link>
              <.link
                navigate={~p"/join"}
                class="btn btn-outline btn-sm font-bold gap-2 w-full sm:w-auto"
              >
                <.icon name="hero-key" class="size-4" /> Entrer un code PIN
              </.link>
            </div>
          </div>

          <div
            :for={{dom_id, game} <- @streams.games}
            id={dom_id}
            class="bg-base-100 border border-base-300 hover:border-emerald-500/50 transition-all rounded-3xl p-6 shadow-xs hover:shadow-md flex flex-col justify-between"
          >
            <div>
              <div class="flex items-start justify-between gap-3 mb-3">
                <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-emerald-100 text-emerald-800 dark:bg-emerald-950/50 dark:text-emerald-300">
                  <span class="size-2 rounded-full bg-emerald-500 animate-pulse"></span>
                  Partie Publique
                </span>

                <span class={[
                  "badge badge-xs font-semibold uppercase tracking-wider",
                  if(game.status == :lobby, do: "badge-primary", else: "badge-secondary")
                ]}>
                  {if game.status == :lobby, do: "En attente", else: "En cours"}
                </span>
              </div>

              <h2 class="text-xl font-bold text-base-content mb-1">
                {game.quiz.title}
              </h2>

              <%= if game.quiz.image_url do %>
                <div class="my-2.5 overflow-hidden rounded-xl border border-base-200">
                  <img
                    src={game.quiz.image_url}
                    alt={game.quiz.title}
                    class="w-full h-32 object-cover"
                    loading="lazy"
                  />
                </div>
              <% end %>

              <p class="text-xs text-base-content/65 line-clamp-2 leading-relaxed">
                {game.quiz.description || "Préparez vos neurones, la partie est ouverte !"}
              </p>
            </div>

            <div class="mt-6 pt-4 border-t border-base-200 flex items-center justify-between">
              <div class="flex items-center gap-3 text-xs text-base-content/60">
                <span class="inline-flex items-center gap-1 font-bold text-primary">
                  <.icon name="hero-users" class="size-4" />
                  {length(Map.keys(game.players || %{}))} joueur{if length(
                                                                      Map.keys(game.players || %{})
                                                                    ) > 1,
                                                                    do: "s",
                                                                    else: ""}
                </span>
                <span class="inline-flex items-center gap-1">
                  <.icon name="hero-question-mark-circle" class="size-4" />
                  {if is_list(game.questions), do: length(game.questions), else: 0} questions
                </span>
              </div>

              <button
                type="button"
                id={"join-game-btn-#{game.code}"}
                phx-click="click_join"
                phx-value-code={game.code}
                class="btn btn-primary btn-sm font-bold gap-1 shadow-xs"
              >
                Rejoindre <.icon name="hero-arrow-right" class="size-4" />
              </button>
            </div>
          </div>
        </div>

        <!-- 3. Modal pour pseudo (utilisateurs anonymes) -->
        <div
          :if={@join_modal_game}
          id="guest-join-modal"
          class="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4 animate-in fade-in"
        >
          <div class="bg-base-100 border border-base-300 rounded-3xl p-6 sm:p-8 max-w-md w-full shadow-2xl relative">
            <button
              type="button"
              id="close-guest-modal-btn"
              phx-click="close_modal"
              class="btn btn-ghost btn-sm btn-circle absolute top-4 right-4"
            >
              <.icon name="hero-x-mark" class="size-5" />
            </button>

            <div class="flex items-center gap-2 mb-2">
              <span class="badge badge-success badge-sm text-white">Partie Publique</span>
              <span class="text-xs text-base-content/50">Pas de code PIN requis</span>
            </div>

            <h3 class="text-2xl font-black mb-1">
              {@join_modal_game.quiz.title}
            </h3>
            <p class="text-xs text-base-content/60 mb-6">
              Choisissez votre pseudo pour rejoindre cette session.
            </p>

            <div :if={@nickname_error} id="guest-join-error" class="alert alert-error text-sm mb-4">
              <.icon name="hero-exclamation-circle" class="size-5 shrink-0" />
              <span>{@nickname_error}</span>
            </div>

            <form id="guest-join-form" phx-submit="submit_guest_join" class="space-y-4">
              <input type="hidden" name="code" value={@join_modal_game.code} />

              <div>
                <label class="label font-bold text-xs mb-1 block">Votre pseudo</label>
                <input
                  type="text"
                  name="nickname"
                  id="guest-nickname-input"
                  placeholder="Ex: ChampionDuQuiz"
                  class="input input-lg w-full font-semibold"
                  maxlength="20"
                  autofocus
                  required
                />
              </div>

              <div class="pt-2 flex gap-3">
                <button
                  type="button"
                  id="cancel-guest-modal-btn"
                  phx-click="close_modal"
                  class="btn btn-ghost btn-md flex-1 font-semibold"
                >
                  Annuler
                </button>
                <button
                  type="submit"
                  id="confirm-guest-join-btn"
                  class="btn btn-primary btn-md flex-1 font-bold shadow-md"
                >
                  Entrer dans le salon <.icon name="hero-arrow-right" class="size-4 ml-1" />
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
