defmodule QuizirWeb.Admin.DashboardLive do
  use QuizirWeb, :live_view

  alias Quizir.Accounts
  alias Quizir.Quizzes
  alias Quizir.Games

  @impl true
  def mount(_params, _session, socket) do
    admin_user = socket.assigns.current_admin_user

    socket =
      socket
      |> assign(:current_scope, %Quizir.Accounts.Scope{user: admin_user})
      |> assign(:page_title, "Administration Quizir")
      |> assign(:active_tab, "users")
      |> assign(:user_search, "")
      |> assign(:quiz_search, "")
      |> reload_stats()
      |> reload_users()
      |> reload_quizzes()
      |> reload_games()

    {:ok, socket}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket)
      when tab in ["users", "quizzes", "games"] do
    socket =
      socket
      |> assign(:active_tab, tab)
      |> reload_stats()

    socket =
      case tab do
        "users" -> reload_users(socket)
        "quizzes" -> reload_quizzes(socket)
        "games" -> reload_games(socket)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("search_users", %{"search" => search}, socket) do
    {:noreply, socket |> assign(:user_search, search) |> reload_users()}
  end

  @impl true
  def handle_event("search_quizzes", %{"search" => search}, socket) do
    {:noreply, socket |> assign(:quiz_search, search) |> reload_quizzes()}
  end

  @impl true
  def handle_event("toggle_admin", %{"user_id" => user_id_str}, socket) do
    user_id = String.to_integer(user_id_str)
    target_user = Accounts.get_user!(user_id)
    current_admin = socket.assigns.current_admin_user
    new_admin_status = not target_user.admin

    case Accounts.update_user_admin(target_user, new_admin_status, current_admin) do
      {:ok, updated_user} ->
        action_name = if new_admin_status, do: "promu administrateur", else: "rétrogradé joueur"

        {:noreply,
         socket
         |> put_flash(:info, "L'utilisateur #{updated_user.username} a été #{action_name}.")
         |> reload_stats()
         |> reload_users()}

      {:error, :cannot_demote_self} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Vous ne pouvez pas retirer vos propres privilèges administrateur."
         )}

      {:error, _changeset} ->
        {:noreply,
         put_flash(socket, :error, "Une erreur est survenue lors de la modification du statut.")}
    end
  end

  @impl true
  def handle_event("delete_user", %{"user_id" => user_id_str}, socket) do
    user_id = String.to_integer(user_id_str)
    target_user = Accounts.get_user!(user_id)
    current_admin = socket.assigns.current_admin_user

    case Accounts.delete_user_by_admin(target_user, current_admin) do
      {:ok, _deleted_user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Le compte de #{target_user.username} a été supprimé.")
         |> reload_stats()
         |> reload_users()
         |> reload_quizzes()}

      {:error, :cannot_delete_self} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Vous ne pouvez pas supprimer votre propre compte administrateur."
         )}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Impossible de supprimer cet utilisateur.")}
    end
  end

  @impl true
  def handle_event("delete_quiz", %{"quiz_id" => quiz_id_str}, socket) do
    quiz_id = String.to_integer(quiz_id_str)
    quiz = Quizzes.get_quiz!(quiz_id)

    case Quizzes.delete_quiz(quiz) do
      {:ok, _deleted_quiz} ->
        {:noreply,
         socket
         |> put_flash(:info, "Le quiz « #{quiz.title} » a été supprimé.")
         |> reload_stats()
         |> reload_quizzes()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Impossible de supprimer ce quiz.")}
    end
  end

  @impl true
  def handle_event("stop_game", %{"code" => code}, socket) do
    case Games.terminate_game_by_admin(code) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "La session de jeu #{code} a été arrêtée.")
         |> reload_stats()
         |> reload_games()}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "La session #{code} n'est plus active.")
         |> reload_games()}
    end
  end

  @impl true
  def handle_event("refresh_games", _params, socket) do
    {:noreply,
     socket
     |> reload_stats()
     |> reload_games()
     |> put_flash(:info, "Liste des parties rafraîchie.")}
  end

  defp reload_stats(socket) do
    user_count = Accounts.count_users()
    admin_count = Accounts.count_admins()
    quiz_count = Quizzes.count_quizzes()
    public_quiz_count = Quizzes.count_public_quizzes()
    private_quiz_count = Quizzes.count_private_quizzes()
    game_count = Games.count_active_games()
    active_games = Games.list_all_active_games()

    connected_players =
      Enum.sum(Enum.map(active_games, fn g -> length(Map.keys(g.players || %{})) end))

    socket
    |> assign(:stats, %{
      user_count: user_count,
      admin_count: admin_count,
      player_count: max(0, user_count - admin_count),
      quiz_count: quiz_count,
      public_quiz_count: public_quiz_count,
      private_quiz_count: private_quiz_count,
      game_count: game_count,
      connected_players: connected_players
    })
  end

  defp reload_users(socket) do
    users = Accounts.list_users(search: socket.assigns.user_search)
    assign(socket, :users, users)
  end

  defp reload_quizzes(socket) do
    quizzes = Quizzes.list_quizzes_for_admin(search: socket.assigns.quiz_search)
    assign(socket, :quizzes, quizzes)
  end

  defp reload_games(socket) do
    games = Games.list_all_active_games()
    assign(socket, :games, games)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      current_admin_user={@current_admin_user}
    >
      <div class="space-y-6">
        <!-- Top Admin Header Banner -->
        <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 p-6 rounded-3xl bg-base-100 border border-base-300 shadow-sm">
          <div class="flex items-center gap-4">
            <div class="p-3 rounded-2xl bg-error/10 text-error ring-1 ring-error/20 shrink-0">
              <.icon name="hero-shield-check" class="size-8" />
            </div>
            <div>
              <div class="flex items-center gap-2">
                <h1 class="text-2xl font-black tracking-tight" id="admin-dashboard-title">
                  Espace d'Administration
                </h1>
                <span class="badge badge-error badge-sm font-bold tracking-wider uppercase text-[10px]">Admin</span>
              </div>
              <p class="text-sm text-zinc-500 mt-0.5">
                Connecté en tant que
                <span class="font-bold text-base-content">{@current_admin_user.username}</span>
                (Session administrateur isolée)
              </p>
            </div>
          </div>

          <div class="flex items-center gap-2 shrink-0">
            <.link navigate={~p"/quizzes"} class="btn btn-ghost btn-sm text-xs font-semibold gap-1.5">
              <.icon name="hero-arrow-top-right-on-square" class="size-4" /> Voir le site
            </.link>
            <.link
              href={~p"/admin/log_out"}
              method="delete"
              id="admin-logout-btn"
              class="btn btn-outline btn-error btn-sm text-xs font-bold gap-1.5"
            >
              <.icon name="hero-arrow-right-on-rectangle" class="size-4" /> Déconnexion Admin
            </.link>
          </div>
        </div>

        <!-- Key Stat Cards -->
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          <!-- Stat Users -->
          <div class="p-5 rounded-2xl bg-base-100 border border-base-300 shadow-sm flex items-center justify-between">
            <div>
              <span class="text-xs font-semibold text-zinc-400 uppercase tracking-wider">Utilisateurs</span>
              <div class="text-3xl font-black mt-1 text-base-content">{@stats.user_count}</div>
              <div class="flex items-center gap-2 text-xs text-zinc-500 mt-1.5">
                <span class="badge badge-sm badge-error font-semibold">{@stats.admin_count} admins</span>
                <span>{@stats.player_count} joueurs</span>
              </div>
            </div>
            <div class="p-3 rounded-2xl bg-primary/10 text-primary">
              <.icon name="hero-users" class="size-7" />
            </div>
          </div>

          <!-- Stat Quizzes -->
          <div class="p-5 rounded-2xl bg-base-100 border border-base-300 shadow-sm flex items-center justify-between">
            <div>
              <span class="text-xs font-semibold text-zinc-400 uppercase tracking-wider">Quiz Créés</span>
              <div class="text-3xl font-black mt-1 text-base-content">{@stats.quiz_count}</div>
              <div class="flex items-center gap-2 text-xs text-zinc-500 mt-1.5">
                <span class="badge badge-sm badge-success font-semibold">{@stats.public_quiz_count} publics</span>
                <span class="badge badge-sm badge-ghost font-semibold">{@stats.private_quiz_count} privés</span>
              </div>
            </div>
            <div class="p-3 rounded-2xl bg-emerald-500/10 text-emerald-500">
              <.icon name="hero-academic-cap" class="size-7" />
            </div>
          </div>

          <!-- Stat Active Games -->
          <div class="p-5 rounded-2xl bg-base-100 border border-base-300 shadow-sm flex items-center justify-between sm:col-span-2 lg:col-span-1">
            <div>
              <span class="text-xs font-semibold text-zinc-400 uppercase tracking-wider">Parties en Direct</span>
              <div class="text-3xl font-black mt-1 text-base-content">{@stats.game_count}</div>
              <div class="text-xs text-zinc-500 mt-1.5 flex items-center gap-1.5">
                <span class="size-2 rounded-full bg-emerald-500 animate-pulse"></span>
                <span>{@stats.connected_players} joueur(s) connecté(s)</span>
              </div>
            </div>
            <div class="p-3 rounded-2xl bg-amber-500/10 text-amber-500">
              <.icon name="hero-play" class="size-7" />
            </div>
          </div>
        </div>

        <!-- Tabbed Navigation -->
        <div class="flex border-b border-base-300 gap-2">
          <button
            phx-click="switch_tab"
            phx-value-tab="users"
            id="tab-users-btn"
            class={[
              "px-4 py-2.5 font-bold text-sm border-b-2 flex items-center gap-2 transition-colors cursor-pointer",
              @active_tab == "users" && "border-primary text-primary",
              @active_tab != "users" && "border-transparent text-zinc-500 hover:text-base-content"
            ]}
          >
            <.icon name="hero-users" class="size-4" /> Utilisateurs ({@stats.user_count})
          </button>

          <button
            phx-click="switch_tab"
            phx-value-tab="quizzes"
            id="tab-quizzes-btn"
            class={[
              "px-4 py-2.5 font-bold text-sm border-b-2 flex items-center gap-2 transition-colors cursor-pointer",
              @active_tab == "quizzes" && "border-primary text-primary",
              @active_tab != "quizzes" && "border-transparent text-zinc-500 hover:text-base-content"
            ]}
          >
            <.icon name="hero-rectangle-stack" class="size-4" /> Tous les Quiz ({@stats.quiz_count})
          </button>

          <button
            phx-click="switch_tab"
            phx-value-tab="games"
            id="tab-games-btn"
            class={[
              "px-4 py-2.5 font-bold text-sm border-b-2 flex items-center gap-2 transition-colors cursor-pointer",
              @active_tab == "games" && "border-primary text-primary",
              @active_tab != "games" && "border-transparent text-zinc-500 hover:text-base-content"
            ]}
          >
            <.icon name="hero-globe-alt" class="size-4" /> Parties en direct ({@stats.game_count})
          </button>
        </div>

        <!-- Tab 1: Users Management -->
        <%= if @active_tab == "users" do %>
          <div class="space-y-4">
            <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <form
                id="admin-search-users-form"
                phx-change="search_users"
                phx-submit="search_users"
                class="w-full sm:max-w-md"
              >
                <div class="relative">
                  <.icon
                    name="hero-magnifying-glass"
                    class="size-5 absolute left-3 top-1/2 -translate-y-1/2 text-zinc-400"
                  />
                  <input
                    type="text"
                    name="search"
                    value={@user_search}
                    id="admin-search-users-input"
                    placeholder="Rechercher par nom d'utilisateur ou email..."
                    class="input input-bordered w-full pl-10 text-sm"
                  />
                </div>
              </form>

              <div class="text-xs text-zinc-500 font-medium">
                {length(@users)} utilisateur(s) affiché(s)
              </div>
            </div>

            <div class="overflow-x-auto rounded-2xl border border-base-300 bg-base-100 shadow-sm">
              <table class="table table-zebra w-full" id="admin-users-table">
                <thead>
                  <tr class="text-zinc-400 text-xs uppercase tracking-wider">
                    <th>ID</th>
                    <th>Utilisateur</th>
                    <th>Email</th>
                    <th>Rôle</th>
                    <th>Inscrit le</th>
                    <th class="text-right">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <%= if @users == [] do %>
                    <tr>
                      <td colspan="6" class="text-center py-8 text-zinc-400">
                        Aucun utilisateur ne correspond à votre recherche.
                      </td>
                    </tr>
                  <% else %>
                    <%= for user <- @users do %>
                      <tr id={"user-row-#{user.id}"} class="hover">
                        <td class="font-mono text-xs text-zinc-400">{user.id}</td>
                        <td class="font-bold">
                          <div class="flex items-center gap-2">
                            <.icon name="hero-user-circle" class="size-5 text-primary" />
                            <span>{user.username}</span>
                            <%= if user.id == @current_admin_user.id do %>
                              <span class="badge badge-ghost badge-xs">(Vous)</span>
                            <% end %>
                          </div>
                        </td>
                        <td class="text-sm">
                          <%= if user.email do %>
                            <span class="text-zinc-600">{user.email}</span>
                          <% else %>
                            <span class="text-zinc-400 italic text-xs">Aucun email</span>
                          <% end %>
                        </td>
                        <td>
                          <%= if user.admin do %>
                            <span class="badge badge-error badge-sm font-bold gap-1 text-[11px]">
                              <.icon name="hero-shield-check" class="size-3.5" /> Administrateur
                            </span>
                          <% else %>
                            <span class="badge badge-ghost badge-sm font-semibold text-zinc-500 text-[11px]">
                              Joueur
                            </span>
                          <% end %>
                        </td>
                        <td class="text-xs text-zinc-500">
                          {Calendar.strftime(user.inserted_at, "%d/%m/%Y %H:%M")}
                        </td>
                        <td class="text-right">
                          <div class="flex items-center justify-end gap-2">
                            <%= if user.id != @current_admin_user.id do %>
                              <button
                                phx-click="toggle_admin"
                                phx-value-user_id={user.id}
                                id={"toggle-admin-btn-#{user.id}"}
                                class={[
                                  "btn btn-xs font-bold",
                                  user.admin && "btn-outline btn-warning",
                                  not user.admin && "btn-outline btn-error"
                                ]}
                                data-confirm={
                                  if user.admin,
                                    do: "Rétrograder #{user.username} en simple joueur ?",
                                    else:
                                      "Accorder les privilèges administrateur complets à #{user.username} ?"
                                }
                              >
                                <%= if user.admin do %>
                                  <.icon name="hero-arrow-down-circle" class="size-3.5" /> Rétrograder
                                <% else %>
                                  <.icon name="hero-shield-check" class="size-3.5" /> Promouvoir Admin
                                <% end %>
                              </button>

                              <button
                                phx-click="delete_user"
                                phx-value-user_id={user.id}
                                id={"delete-user-btn-#{user.id}"}
                                class="btn btn-xs btn-ghost text-error hover:bg-error/10"
                                data-confirm={"Êtes-vous sûr de vouloir supprimer définitivement le compte de #{user.username} ?"}
                              >
                                <.icon name="hero-trash" class="size-4" />
                              </button>
                            <% else %>
                              <span class="text-xs text-zinc-400 italic pr-2">Session active</span>
                            <% end %>
                          </div>
                        </td>
                      </tr>
                    <% end %>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        <% end %>

        <!-- Tab 2: Quizzes Management -->
        <%= if @active_tab == "quizzes" do %>
          <div class="space-y-4">
            <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <form
                id="admin-search-quizzes-form"
                phx-change="search_quizzes"
                phx-submit="search_quizzes"
                class="w-full sm:max-w-md"
              >
                <div class="relative">
                  <.icon
                    name="hero-magnifying-glass"
                    class="size-5 absolute left-3 top-1/2 -translate-y-1/2 text-zinc-400"
                  />
                  <input
                    type="text"
                    name="search"
                    value={@quiz_search}
                    id="admin-search-quizzes-input"
                    placeholder="Rechercher par titre ou description..."
                    class="input input-bordered w-full pl-10 text-sm"
                  />
                </div>
              </form>

              <div class="text-xs text-zinc-500 font-medium">
                {length(@quizzes)} quiz affiché(s)
              </div>
            </div>

            <div class="overflow-x-auto rounded-2xl border border-base-300 bg-base-100 shadow-sm">
              <table class="table table-zebra w-full" id="admin-quizzes-table">
                <thead>
                  <tr class="text-zinc-400 text-xs uppercase tracking-wider">
                    <th>ID</th>
                    <th>Titre</th>
                    <th>Créateur</th>
                    <th>Visibilité</th>
                    <th>Questions</th>
                    <th>Créé le</th>
                    <th class="text-right">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <%= if @quizzes == [] do %>
                    <tr>
                      <td colspan="7" class="text-center py-8 text-zinc-400">
                        Aucun quiz ne correspond à votre recherche.
                      </td>
                    </tr>
                  <% else %>
                    <%= for quiz <- @quizzes do %>
                      <tr id={"quiz-row-#{quiz.id}"} class="hover">
                        <td class="font-mono text-xs text-zinc-400">{quiz.id}</td>
                        <td class="font-bold">
                          <span class="text-base-content">{quiz.title}</span>
                        </td>
                        <td class="text-sm">
                          <%= if quiz.user do %>
                            <span class="font-medium text-primary">{quiz.user.username}</span>
                          <% else %>
                            <span class="text-zinc-400 italic">Anonyme</span>
                          <% end %>
                        </td>
                        <td>
                          <%= if quiz.visibility == "public" do %>
                            <span class="badge badge-success badge-sm font-bold text-[11px]">
                              Public
                            </span>
                          <% else %>
                            <span class="badge badge-ghost badge-sm font-bold text-[11px] text-zinc-500">
                              <.icon name="hero-lock-closed" class="size-3 mr-0.5" /> Privé
                            </span>
                          <% end %>
                        </td>
                        <td class="text-sm font-semibold">
                          {length(quiz.questions || [])}
                        </td>
                        <td class="text-xs text-zinc-500">
                          {Calendar.strftime(quiz.inserted_at, "%d/%m/%Y %H:%M")}
                        </td>
                        <td class="text-right">
                          <div class="flex items-center justify-end gap-2">
                            <.link
                              navigate={~p"/quizzes/#{quiz.id}"}
                              class="btn btn-xs btn-ghost text-primary"
                              title="Voir le quiz"
                            >
                              <.icon name="hero-eye" class="size-4" />
                            </.link>

                            <button
                              phx-click="delete_quiz"
                              phx-value-quiz_id={quiz.id}
                              id={"delete-quiz-btn-#{quiz.id}"}
                              class="btn btn-xs btn-ghost text-error hover:bg-error/10"
                              data-confirm={"Êtes-vous sûr de vouloir supprimer définitivement le quiz « #{quiz.title} » ?"}
                              title="Supprimer le quiz"
                            >
                              <.icon name="hero-trash" class="size-4" />
                            </button>
                          </div>
                        </td>
                      </tr>
                    <% end %>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        <% end %>

        <!-- Tab 3: Active Games Supervision -->
        <%= if @active_tab == "games" do %>
          <div class="space-y-4">
            <div class="flex items-center justify-between">
              <div class="text-sm text-zinc-500 font-medium">
                Parties multijoueurs actuellement en mémoire sur le serveur
              </div>

              <button
                phx-click="refresh_games"
                id="admin-refresh-games-btn"
                class="btn btn-sm btn-ghost gap-1.5 text-xs font-semibold"
              >
                <.icon name="hero-arrow-path" class="size-4" /> Rafraîchir
              </button>
            </div>

            <div class="overflow-x-auto rounded-2xl border border-base-300 bg-base-100 shadow-sm">
              <table class="table table-zebra w-full" id="admin-games-table">
                <thead>
                  <tr class="text-zinc-400 text-xs uppercase tracking-wider">
                    <th>Code PIN</th>
                    <th>Quiz</th>
                    <th>Hôte</th>
                    <th>Visibilité</th>
                    <th>Joueurs</th>
                    <th>Statut</th>
                    <th class="text-right">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <%= if @games == [] do %>
                    <tr>
                      <td colspan="7" class="text-center py-12 text-zinc-400">
                        <div class="inline-flex p-3 rounded-2xl bg-base-200 text-zinc-400 mb-2">
                          <.icon name="hero-play-pause" class="size-6" />
                        </div>
                        <p class="font-medium">Aucune partie active pour le moment.</p>
                      </td>
                    </tr>
                  <% else %>
                    <%= for game <- @games do %>
                      <tr id={"game-row-#{game.code}"} class="hover">
                        <td class="font-mono text-sm font-black text-primary">
                          {game.code}
                        </td>
                        <td class="font-bold">
                          {game.quiz.title}
                        </td>
                        <td class="text-sm">
                          <%= if game.quiz && Ecto.assoc_loaded?(game.quiz.user) && game.quiz.user do %>
                            <span class="font-semibold text-base-content">{game.quiz.user.username}</span>
                          <% else %>
                            <span class="text-zinc-400 italic">Anonyme</span>
                          <% end %>
                        </td>
                        <td>
                          <%= if to_string(game.visibility) == "public" do %>
                            <span class="badge badge-success badge-sm text-[11px] font-bold">Public</span>
                          <% else %>
                            <span class="badge badge-ghost badge-sm text-[11px] font-bold text-zinc-500">Privé</span>
                          <% end %>
                        </td>
                        <td class="text-sm font-bold">
                          <span class="badge badge-primary badge-sm font-bold">
                            {length(Map.keys(game.players || %{}))} joueurs
                          </span>
                        </td>
                        <td>
                          <span class="badge badge-outline badge-sm capitalize text-[11px]">
                            {to_string(game.status)}
                          </span>
                        </td>
                        <td class="text-right">
                          <button
                            phx-click="stop_game"
                            phx-value-code={game.code}
                            id={"stop-game-btn-#{game.code}"}
                            class="btn btn-xs btn-outline btn-error font-bold"
                            data-confirm={"Voulez-vous forcer l'arrêt de la partie #{game.code} ?"}
                          >
                            <.icon name="hero-stop" class="size-3.5" /> Forcer l'arrêt
                          </button>
                        </td>
                      </tr>
                    <% end %>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
