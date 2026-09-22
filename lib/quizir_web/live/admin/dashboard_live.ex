defmodule QuizirWeb.Admin.DashboardLive do
  use QuizirWeb, :live_view

  alias Quizir.Accounts
  alias Quizir.Quizzes
  alias Quizir.Games

  @impl true
  def mount(params, _session, socket) do
    admin_user = socket.assigns.current_admin_user
    requested_tab = Map.get(params, "tab", "stats")

    active_tab =
      if requested_tab in ["stats", "users", "quizzes", "games"], do: requested_tab, else: "stats"

    socket =
      socket
      |> assign(:current_scope, %Quizir.Accounts.Scope{user: admin_user})
      |> assign(:page_title, "Administration Quizir - Statistiques & Gestion")
      |> assign(:active_tab, active_tab)
      |> assign(:user_search, "")
      |> assign(:quiz_search, "")
      |> reload_stats()
      |> reload_users()
      |> reload_quizzes()
      |> reload_games()
      |> reload_completed_games()

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Quizir.PubSub, "site:presence")
      Phoenix.PubSub.subscribe(Quizir.PubSub, "admin:dashboard")
      schedule_stats_tick()
    end

    {:ok, socket}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket)
      when tab in ["stats", "users", "quizzes", "games"] do
    socket =
      socket
      |> assign(:active_tab, tab)
      |> reload_stats()

    socket =
      case tab do
        "stats" -> reload_completed_games(socket)
        "users" -> reload_users(socket)
        "quizzes" -> reload_quizzes(socket)
        "games" -> socket |> reload_games() |> reload_completed_games()
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh_stats", _params, socket) do
    {:noreply,
     socket
     |> reload_stats()
     |> reload_games()
     |> reload_completed_games()
     |> put_flash(:info, "Statistiques actualisées en direct.")}
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
     |> reload_completed_games()
     |> put_flash(:info, "Liste des parties rafraîchie.")}
  end

  defp reload_stats(socket) do
    connected_stats = QuizirWeb.UserTracker.get_connected_stats()

    user_count = Accounts.count_users()
    admin_count = Accounts.count_admins()
    player_count = Accounts.count_players()
    users_with_email = Accounts.count_users_with_email()
    users_without_email = Accounts.count_users_without_email()

    quiz_count = Quizzes.count_quizzes()
    public_quiz_count = Quizzes.count_public_quizzes()
    private_quiz_count = Quizzes.count_private_quizzes()
    question_count = Quizzes.count_questions()
    option_count = Quizzes.count_answer_options()
    avg_questions_per_quiz = Quizzes.avg_questions_per_quiz()

    active_stats = Games.get_active_games_stats()

    completed_games_count = Games.count_completed_games()
    total_participants = Games.count_total_participants()
    avg_players_per_game = Games.avg_players_per_completed_game()

    socket
    |> assign(:stats, %{
      # Live Connected (Presence)
      connected_total: connected_stats.total,
      connected_guests: connected_stats.guests,
      connected_registered: connected_stats.registered,
      connected_distinct_users: connected_stats.distinct_users,

      # Users
      user_count: user_count,
      admin_count: admin_count,
      player_count: player_count,
      users_with_email: users_with_email,
      users_without_email: users_without_email,

      # Quizzes
      quiz_count: quiz_count,
      public_quiz_count: public_quiz_count,
      private_quiz_count: private_quiz_count,
      question_count: question_count,
      option_count: option_count,
      avg_questions_per_quiz: avg_questions_per_quiz,

      # Active Games
      active_games_count: active_stats.total,
      active_lobby_count: active_stats.lobby,
      active_in_game_count: active_stats.in_game,
      active_finished_count: active_stats.finished,
      active_players_count: active_stats.total_players,
      game_count: active_stats.total,
      connected_players: active_stats.total_players,

      # Completed Games
      completed_games_count: completed_games_count,
      total_participants: total_participants,
      avg_players_per_game: avg_players_per_game
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

  defp reload_completed_games(socket) do
    completed_games = Games.list_recent_completed_games(25)
    assign(socket, :completed_games, completed_games)
  end

  defp schedule_stats_tick do
    Process.send_after(self(), :tick_stats, 4000)
  end

  # --- Real-Time PubSub Handlers ---

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    {:noreply, reload_stats(socket)}
  end

  @impl true
  def handle_info({:presence_diff, _diff}, socket) do
    {:noreply, reload_stats(socket)}
  end

  @impl true
  def handle_info({:admin_game_event, _action, _payload}, socket) do
    {:noreply,
     socket
     |> reload_stats()
     |> reload_games()
     |> reload_completed_games()}
  end

  @impl true
  def handle_info({:admin_content_event, :quizzes}, socket) do
    {:noreply,
     socket
     |> reload_stats()
     |> reload_quizzes()}
  end

  @impl true
  def handle_info({:admin_content_event, :users}, socket) do
    {:noreply,
     socket
     |> reload_stats()
     |> reload_users()}
  end

  @impl true
  def handle_info(:tick_stats, socket) do
    if connected?(socket) do
      schedule_stats_tick()
    end

    {:noreply,
     socket
     |> reload_stats()
     |> reload_games()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      current_admin_user={@current_admin_user}
      is_admin={true}
      container_class="mx-auto max-w-7xl space-y-6"
    >
      <div class="space-y-6">
        <!-- Top Admin Header Banner -->
        <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 p-6 rounded-3xl bg-base-100 border border-base-300 shadow-sm">
          <div class="flex items-center gap-4">
            <div class="p-3.5 rounded-2xl bg-error/10 text-error ring-1 ring-error/20 shrink-0">
              <.icon name="hero-shield-check" class="size-8" />
            </div>
            <div>
              <div class="flex items-center gap-2">
                <h1 class="text-2xl font-black tracking-tight" id="admin-dashboard-title">
                  Espace d'Administration
                </h1>
                <span class="badge badge-error badge-sm font-bold tracking-wider uppercase text-[10px]">
                  Admin
                </span>
                <span
                  id="admin-live-badge"
                  class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-[11px] font-bold bg-emerald-500/10 text-emerald-600 border border-emerald-500/20 shadow-2xs"
                  title="Données synchronisées en temps réel via Phoenix LiveView"
                >
                  <span class="relative flex size-2">
                    <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                    <span class="relative inline-flex rounded-full size-2 bg-emerald-500"></span>
                  </span>
                  <span>Temps réel</span>
                </span>
              </div>
              <p class="text-sm text-zinc-500 mt-0.5">
                Connecté en tant que
                <span class="font-bold text-base-content">{@current_admin_user.username}</span>
                (Session administrateur isolée)
              </p>
            </div>
          </div>

          <div class="flex items-center gap-2 shrink-0">
            <button
              phx-click="refresh_stats"
              id="admin-global-refresh-btn"
              class="btn btn-ghost btn-sm text-xs font-semibold gap-1.5"
              title="Rafraîchir toutes les métriques"
            >
              <.icon name="hero-arrow-path" class="size-4" /> Actualiser
            </button>
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

        <!-- Key Stat Cards (4 columns on lg) -->
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4" id="admin-kpi-cards">
          <!-- Card 1: Live Connected Users -->
          <div class="p-5 rounded-2xl bg-base-100 border border-base-300 shadow-sm flex flex-col justify-between">
            <div class="flex items-center justify-between">
              <span class="text-xs font-bold text-zinc-400 uppercase tracking-wider">
                En direct sur le site
              </span>
              <span class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-[10px] font-black bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-500/20">
                <span class="size-2 rounded-full bg-emerald-500 animate-pulse"></span> Live
              </span>
            </div>
            <div class="my-2">
              <div class="text-3xl font-black text-base-content" id="stat-connected-total">
                {@stats.connected_total}
              </div>
              <p class="text-xs text-zinc-500 mt-1">utilisateurs connectés actuellement</p>
            </div>
            <div class="pt-2 border-t border-base-200 flex items-center justify-between text-xs text-zinc-500">
              <span class="badge badge-sm badge-ghost font-semibold">
                {@stats.connected_guests} invités
              </span>
              <span class="badge badge-sm badge-primary font-semibold">
                {@stats.connected_registered} inscrits
              </span>
            </div>
          </div>

          <!-- Card 2: Multiplayer Games (Live & Completed) -->
          <div class="p-5 rounded-2xl bg-base-100 border border-base-300 shadow-sm flex flex-col justify-between">
            <div class="flex items-center justify-between">
              <span class="text-xs font-bold text-zinc-400 uppercase tracking-wider">
                Parties Multijoueurs
              </span>
              <div class="p-2 rounded-xl bg-amber-500/10 text-amber-500">
                <.icon name="hero-play" class="size-4" />
              </div>
            </div>
            <div class="my-2">
              <div class="flex items-baseline gap-2">
                <span class="text-3xl font-black text-amber-500" id="stat-active-games">
                  {@stats.active_games_count}
                </span>
                <span class="text-sm font-bold text-zinc-400">en cours</span>
                <span class="text-zinc-300 dark:text-zinc-700">|</span>
                <span class="text-2xl font-black text-base-content" id="stat-completed-games">
                  {@stats.completed_games_count}
                </span>
                <span class="text-sm font-bold text-zinc-400">finies</span>
              </div>
              <p class="text-xs text-zinc-500 mt-1">
                {@stats.active_players_count} joueurs actuellement en jeu
              </p>
            </div>
            <div class="pt-2 border-t border-base-200 flex items-center justify-between text-xs text-zinc-500">
              <span>
                {if @stats.completed_games_count > 0,
                  do: "#{@stats.avg_players_per_game} j/partie",
                  else: "0 j/partie"}
              </span>
              <span class="font-semibold text-amber-600 dark:text-amber-400">
                {@stats.total_participants} part. totales
              </span>
            </div>
          </div>

          <!-- Card 3: Quizzes Library -->
          <div class="p-5 rounded-2xl bg-base-100 border border-base-300 shadow-sm flex flex-col justify-between">
            <div class="flex items-center justify-between">
              <span class="text-xs font-bold text-zinc-400 uppercase tracking-wider">
                Bibliothèque de Quiz
              </span>
              <div class="p-2 rounded-xl bg-emerald-500/10 text-emerald-500">
                <.icon name="hero-rectangle-stack" class="size-4" />
              </div>
            </div>
            <div class="my-2">
              <div class="text-3xl font-black text-base-content" id="stat-quiz-total">
                {@stats.quiz_count}
              </div>
              <p class="text-xs text-zinc-500 mt-1">
                {@stats.question_count} questions au total (moy. {@stats.avg_questions_per_quiz}/quiz)
              </p>
            </div>
            <div class="pt-2 border-t border-base-200 flex items-center justify-between text-xs text-zinc-500">
              <span class="badge badge-sm badge-success font-semibold">
                {@stats.public_quiz_count} publics
              </span>
              <span class="badge badge-sm badge-ghost font-semibold">
                {@stats.private_quiz_count} privés
              </span>
            </div>
          </div>

          <!-- Card 4: Registered Users -->
          <div class="p-5 rounded-2xl bg-base-100 border border-base-300 shadow-sm flex flex-col justify-between">
            <div class="flex items-center justify-between">
              <span class="text-xs font-bold text-zinc-400 uppercase tracking-wider">
                Comptes Utilisateurs
              </span>
              <div class="p-2 rounded-xl bg-primary/10 text-primary">
                <.icon name="hero-users" class="size-4" />
              </div>
            </div>
            <div class="my-2">
              <div class="text-3xl font-black text-base-content" id="stat-user-total">
                {@stats.user_count}
              </div>
              <p class="text-xs text-zinc-500 mt-1">
                {@stats.users_with_email} avec adresse email
              </p>
            </div>
            <div class="pt-2 border-t border-base-200 flex items-center justify-between text-xs text-zinc-500">
              <span class="badge badge-sm badge-error font-semibold">
                {@stats.admin_count} admins
              </span>
              <span class="badge badge-sm badge-ghost font-semibold">
                {@stats.player_count} joueurs
              </span>
            </div>
          </div>
        </div>

        <!-- Tabbed Navigation -->
        <div class="flex border-b border-base-300 gap-2 overflow-x-auto">
          <button
            phx-click="switch_tab"
            phx-value-tab="stats"
            id="tab-stats-btn"
            class={[
              "px-4 py-2.5 font-bold text-sm border-b-2 flex items-center gap-2 transition-colors cursor-pointer shrink-0",
              @active_tab == "stats" && "border-primary text-primary",
              @active_tab != "stats" && "border-transparent text-zinc-500 hover:text-base-content"
            ]}
          >
            <.icon name="hero-chart-bar" class="size-4" /> Statistiques & Métriques
          </button>

          <button
            phx-click="switch_tab"
            phx-value-tab="users"
            id="tab-users-btn"
            class={[
              "px-4 py-2.5 font-bold text-sm border-b-2 flex items-center gap-2 transition-colors cursor-pointer shrink-0",
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
              "px-4 py-2.5 font-bold text-sm border-b-2 flex items-center gap-2 transition-colors cursor-pointer shrink-0",
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
              "px-4 py-2.5 font-bold text-sm border-b-2 flex items-center gap-2 transition-colors cursor-pointer shrink-0",
              @active_tab == "games" && "border-primary text-primary",
              @active_tab != "games" && "border-transparent text-zinc-500 hover:text-base-content"
            ]}
          >
            <.icon name="hero-globe-alt" class="size-4" />
            Parties ({@stats.active_games_count} en direct)
          </button>
        </div>

        <!-- Tab 0: Detailed Statistics View -->
        <%= if @active_tab == "stats" do %>
          <div class="space-y-6" id="admin-stats-view">
            <!-- Grid 2 columns: Users / Presence vs Parties Metrics -->
            <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <!-- Panel 1: Audience en Direct & Utilisateurs Connectés -->
              <div class="p-6 rounded-3xl bg-base-100 border border-base-300 shadow-sm space-y-4">
                <div class="flex items-center justify-between pb-3 border-b border-base-200">
                  <div class="flex items-center gap-2.5">
                    <div class="p-2 rounded-xl bg-emerald-500/10 text-emerald-500">
                      <.icon name="hero-signal" class="size-5" />
                    </div>
                    <div>
                      <h2 class="font-black text-lg text-base-content">
                        Audience & Sessions en Direct
                      </h2>
                      <p class="text-xs text-zinc-500">
                        Suivi temps réel des connexions Phoenix Presence
                      </p>
                    </div>
                  </div>
                  <button
                    phx-click="refresh_stats"
                    id="stats-refresh-btn"
                    class="btn btn-ghost btn-xs text-zinc-400 hover:text-primary gap-1"
                    title="Actualiser les métriques"
                  >
                    <.icon name="hero-arrow-path" class="size-3.5" /> Actualiser
                  </button>
                </div>

                <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
                  <div class="p-3.5 rounded-2xl bg-base-200/50 border border-base-200 text-center">
                    <div class="text-2xl font-black text-base-content">
                      {@stats.connected_total}
                    </div>
                    <div class="text-[11px] font-semibold text-zinc-500 uppercase mt-0.5">
                      Sessions actives
                    </div>
                  </div>
                  <div class="p-3.5 rounded-2xl bg-base-200/50 border border-base-200 text-center">
                    <div class="text-2xl font-black text-zinc-600 dark:text-zinc-300">
                      {@stats.connected_guests}
                    </div>
                    <div class="text-[11px] font-semibold text-zinc-500 uppercase mt-0.5">
                      Invités (Guests)
                    </div>
                  </div>
                  <div class="p-3.5 rounded-2xl bg-base-200/50 border border-base-200 text-center">
                    <div class="text-2xl font-black text-primary">
                      {@stats.connected_registered}
                    </div>
                    <div class="text-[11px] font-semibold text-zinc-500 uppercase mt-0.5">
                      Membres connectés
                    </div>
                  </div>
                  <div class="p-3.5 rounded-2xl bg-base-200/50 border border-base-200 text-center">
                    <div class="text-2xl font-black text-amber-500">
                      {@stats.active_players_count}
                    </div>
                    <div class="text-[11px] font-semibold text-zinc-500 uppercase mt-0.5">
                      Joueurs en jeu
                    </div>
                  </div>
                </div>

                <!-- Proportion Bar: Invités vs Membres -->
                <div class="space-y-1.5 pt-2">
                  <div class="flex justify-between text-xs font-semibold">
                    <span class="text-zinc-500">Répartition des visiteurs en direct</span>
                    <span>
                      <%= if @stats.connected_total > 0 do %>
                        {round(@stats.connected_guests * 100 / max(1, @stats.connected_total))}% Invités / {round(
                          @stats.connected_registered * 100 / max(1, @stats.connected_total)
                        )}% Inscrits
                      <% else %>
                        0 session active
                      <% end %>
                    </span>
                  </div>
                  <div class="w-full h-3 rounded-full bg-base-200 overflow-hidden flex">
                    <%= if @stats.connected_total > 0 do %>
                      <div
                        class="bg-zinc-400 dark:bg-zinc-600 h-full transition-all"
                        style={"width: #{round(@stats.connected_guests * 100 / @stats.connected_total)}%"}
                        title={"Invités: #{@stats.connected_guests}"}
                      >
                      </div>
                      <div
                        class="bg-primary h-full transition-all"
                        style={"width: #{100 - round(@stats.connected_guests * 100 / @stats.connected_total)}%"}
                        title={"Inscrits: #{@stats.connected_registered}"}
                      >
                      </div>
                    <% else %>
                      <div class="w-full bg-base-300 h-full"></div>
                    <% end %>
                  </div>
                  <div class="flex items-center gap-4 text-[11px] text-zinc-500 pt-1">
                    <span class="flex items-center gap-1.5">
                      <span class="size-2.5 rounded-full bg-zinc-400 dark:bg-zinc-600"></span>
                      Invités sans compte ({@stats.connected_guests})
                    </span>
                    <span class="flex items-center gap-1.5">
                      <span class="size-2.5 rounded-full bg-primary"></span>
                      Utilisateurs authentifiés ({@stats.connected_registered})
                    </span>
                  </div>
                </div>
              </div>

              <!-- Panel 2: Parties Multijoueurs Réalisées & En Cours -->
              <div class="p-6 rounded-3xl bg-base-100 border border-base-300 shadow-sm space-y-4">
                <div class="flex items-center gap-2.5 pb-3 border-b border-base-200">
                  <div class="p-2 rounded-xl bg-amber-500/10 text-amber-500">
                    <.icon name="hero-trophy" class="size-5" />
                  </div>
                  <div>
                    <h2 class="font-black text-lg text-base-content">Parties Multijoueurs</h2>
                    <p class="text-xs text-zinc-500">Statistiques de jeu et engagement</p>
                  </div>
                </div>

                <div class="grid grid-cols-2 sm:grid-cols-3 gap-3">
                  <div class="p-3.5 rounded-2xl bg-base-200/50 border border-base-200">
                    <span class="text-[11px] font-bold text-zinc-400 uppercase">
                      Parties Réalisées
                    </span>
                    <div class="text-2xl font-black text-base-content mt-1">
                      {@stats.completed_games_count}
                    </div>
                    <p class="text-[11px] text-zinc-500 mt-0.5">archivées en base</p>
                  </div>
                  <div class="p-3.5 rounded-2xl bg-base-200/50 border border-base-200">
                    <span class="text-[11px] font-bold text-zinc-400 uppercase">
                      Participations
                    </span>
                    <div class="text-2xl font-black text-amber-500 mt-1">
                      {@stats.total_participants}
                    </div>
                    <p class="text-[11px] text-zinc-500 mt-0.5">joueurs cumulés</p>
                  </div>
                  <div class="p-3.5 rounded-2xl bg-base-200/50 border border-base-200 col-span-2 sm:col-span-1">
                    <span class="text-[11px] font-bold text-zinc-400 uppercase">Moyenne</span>
                    <div class="text-2xl font-black text-base-content mt-1">
                      {@stats.avg_players_per_game}
                    </div>
                    <p class="text-[11px] text-zinc-500 mt-0.5">joueurs par partie</p>
                  </div>
                </div>

                <!-- Active games breakdown -->
                <div class="p-4 rounded-2xl bg-amber-500/5 border border-amber-500/20 space-y-2">
                  <div class="flex items-center justify-between text-xs font-bold text-amber-700 dark:text-amber-400">
                    <span class="flex items-center gap-1.5">
                      <span class="size-2 rounded-full bg-amber-500 animate-pulse"></span>
                      {@stats.active_games_count} partie(s) en mémoire actuellement
                    </span>
                    <span>{@stats.active_players_count} joueurs connectés</span>
                  </div>
                  <div class="grid grid-cols-3 gap-2 text-center text-xs pt-1">
                    <div class="p-2 rounded-xl bg-base-100 border border-base-200">
                      <div class="font-black text-base">{@stats.active_lobby_count}</div>
                      <div class="text-[10px] text-zinc-500">Salons (Lobby)</div>
                    </div>
                    <div class="p-2 rounded-xl bg-base-100 border border-base-200">
                      <div class="font-black text-base text-primary">
                        {@stats.active_in_game_count}
                      </div>
                      <div class="text-[10px] text-zinc-500">En jeu (Questions)</div>
                    </div>
                    <div class="p-2 rounded-xl bg-base-100 border border-base-200">
                      <div class="font-black text-base text-emerald-500">
                        {@stats.active_finished_count}
                      </div>
                      <div class="text-[10px] text-zinc-500">Podium (Fin)</div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <!-- Grid 2 columns: Quizzes & Questions vs Accounts Breakdown -->
            <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <!-- Panel 3: Quiz Publics vs Privés & Questions -->
              <div class="p-6 rounded-3xl bg-base-100 border border-base-300 shadow-sm space-y-4">
                <div class="flex items-center gap-2.5 pb-3 border-b border-base-200">
                  <div class="p-2 rounded-xl bg-primary/10 text-primary">
                    <.icon name="hero-academic-cap" class="size-5" />
                  </div>
                  <div>
                    <h2 class="font-black text-lg text-base-content">
                      Quiz & Contenu Pédagogique
                    </h2>
                    <p class="text-xs text-zinc-500">Visibilité et volume de questions créées</p>
                  </div>
                </div>

                <div class="grid grid-cols-2 sm:grid-cols-3 gap-3">
                  <div class="p-3.5 rounded-2xl bg-base-200/50 border border-base-200">
                    <span class="text-[11px] font-bold text-zinc-400 uppercase">Total Quiz</span>
                    <div class="text-2xl font-black text-base-content mt-1">{@stats.quiz_count}</div>
                    <div class="flex items-center gap-1.5 text-xs text-zinc-500 mt-1">
                      <span class="text-emerald-500 font-bold">
                        {@stats.public_quiz_count} publics
                      </span>
                    </div>
                  </div>
                  <div class="p-3.5 rounded-2xl bg-base-200/50 border border-base-200">
                    <span class="text-[11px] font-bold text-zinc-400 uppercase">Questions</span>
                    <div class="text-2xl font-black text-primary mt-1">
                      {@stats.question_count}
                    </div>
                    <p class="text-[11px] text-zinc-500 mt-1">
                      moy. {@stats.avg_questions_per_quiz}/quiz
                    </p>
                  </div>
                  <div class="p-3.5 rounded-2xl bg-base-200/50 border border-base-200 col-span-2 sm:col-span-1">
                    <span class="text-[11px] font-bold text-zinc-400 uppercase">
                      Options / Choix
                    </span>
                    <div class="text-2xl font-black text-base-content mt-1">
                      {@stats.option_count}
                    </div>
                    <p class="text-[11px] text-zinc-500 mt-1">réponses enregistrées</p>
                  </div>
                </div>

                <!-- Public vs Private Breakdown Bar -->
                <div class="space-y-1.5 pt-2">
                  <div class="flex justify-between text-xs font-semibold">
                    <span class="text-zinc-500">Visibilité des quiz</span>
                    <span>
                      <%= if @stats.quiz_count > 0 do %>
                        {round(@stats.public_quiz_count * 100 / max(1, @stats.quiz_count))}% Publics / {round(
                          @stats.private_quiz_count * 100 / max(1, @stats.quiz_count)
                        )}% Privés
                      <% else %>
                        0 quiz
                      <% end %>
                    </span>
                  </div>
                  <div class="w-full h-3 rounded-full bg-base-200 overflow-hidden flex">
                    <%= if @stats.quiz_count > 0 do %>
                      <div
                        class="bg-emerald-500 h-full transition-all"
                        style={"width: #{round(@stats.public_quiz_count * 100 / @stats.quiz_count)}%"}
                        title={"Publics: #{@stats.public_quiz_count}"}
                      >
                      </div>
                      <div
                        class="bg-zinc-400 dark:bg-zinc-600 h-full transition-all"
                        style={"width: #{100 - round(@stats.public_quiz_count * 100 / @stats.quiz_count)}%"}
                        title={"Privés: #{@stats.private_quiz_count}"}
                      >
                      </div>
                    <% else %>
                      <div class="w-full bg-base-300 h-full"></div>
                    <% end %>
                  </div>
                  <div class="flex items-center gap-4 text-[11px] text-zinc-500 pt-1">
                    <span class="flex items-center gap-1.5">
                      <span class="size-2.5 rounded-full bg-emerald-500"></span>
                      Quiz Publics ({@stats.public_quiz_count})
                    </span>
                    <span class="flex items-center gap-1.5">
                      <span class="size-2.5 rounded-full bg-zinc-400 dark:bg-zinc-600"></span>
                      Quiz Privés ({@stats.private_quiz_count})
                    </span>
                  </div>
                </div>
              </div>

              <!-- Panel 4: Base Utilisateurs & Comptes -->
              <div class="p-6 rounded-3xl bg-base-100 border border-base-300 shadow-sm space-y-4">
                <div class="flex items-center gap-2.5 pb-3 border-b border-base-200">
                  <div class="p-2 rounded-xl bg-purple-500/10 text-purple-500">
                    <.icon name="hero-user-group" class="size-5" />
                  </div>
                  <div>
                    <h2 class="font-black text-lg text-base-content">
                      Comptes & Utilisateurs Inscrits
                    </h2>
                    <p class="text-xs text-zinc-500">Structure des rôles et coordonnées</p>
                  </div>
                </div>

                <div class="grid grid-cols-2 gap-3">
                  <div class="p-4 rounded-2xl bg-base-200/50 border border-base-200 flex items-center justify-between">
                    <div>
                      <span class="text-[11px] font-bold text-zinc-400 uppercase">
                        Administrateurs
                      </span>
                      <div class="text-2xl font-black text-error mt-0.5">{@stats.admin_count}</div>
                      <p class="text-[11px] text-zinc-500">accès au portail /admin</p>
                    </div>
                    <div class="p-2 rounded-xl bg-error/10 text-error">
                      <.icon name="hero-shield-check" class="size-5" />
                    </div>
                  </div>

                  <div class="p-4 rounded-2xl bg-base-200/50 border border-base-200 flex items-center justify-between">
                    <div>
                      <span class="text-[11px] font-bold text-zinc-400 uppercase">Joueurs</span>
                      <div class="text-2xl font-black text-base-content mt-0.5">
                        {@stats.player_count}
                      </div>
                      <p class="text-[11px] text-zinc-500">comptes réguliers</p>
                    </div>
                    <div class="p-2 rounded-xl bg-primary/10 text-primary">
                      <.icon name="hero-user" class="size-5" />
                    </div>
                  </div>

                  <div class="p-4 rounded-2xl bg-base-200/50 border border-base-200 flex items-center justify-between">
                    <div>
                      <span class="text-[11px] font-bold text-zinc-400 uppercase">Avec Email</span>
                      <div class="text-2xl font-black text-base-content mt-0.5">
                        {@stats.users_with_email}
                      </div>
                      <p class="text-[11px] text-zinc-500">réinitialisation activable</p>
                    </div>
                    <div class="p-2 rounded-xl bg-emerald-500/10 text-emerald-500">
                      <.icon name="hero-envelope" class="size-5" />
                    </div>
                  </div>

                  <div class="p-4 rounded-2xl bg-base-200/50 border border-base-200 flex items-center justify-between">
                    <div>
                      <span class="text-[11px] font-bold text-zinc-400 uppercase">Sans Email</span>
                      <div class="text-2xl font-black text-zinc-500 mt-0.5">
                        {@stats.users_without_email}
                      </div>
                      <p class="text-[11px] text-zinc-500">pseudo uniquement</p>
                    </div>
                    <div class="p-2 rounded-xl bg-zinc-500/10 text-zinc-500">
                      <.icon name="hero-user-minus" class="size-5" />
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <!-- Panel 5: Dernières Parties Réalisées -->
            <div class="p-6 rounded-3xl bg-base-100 border border-base-300 shadow-sm space-y-4">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2.5">
                  <div class="p-2 rounded-xl bg-amber-500/10 text-amber-500">
                    <.icon name="hero-clock" class="size-5" />
                  </div>
                  <div>
                    <h2 class="font-black text-lg text-base-content">
                      Dernières Parties Réalisées
                    </h2>
                    <p class="text-xs text-zinc-500">
                      Historique des parties complétées avec podium
                    </p>
                  </div>
                </div>
                <span class="badge badge-sm badge-ghost font-semibold">
                  {length(@completed_games)} partie(s) récente(s)
                </span>
              </div>

              <div class="overflow-x-auto rounded-2xl border border-base-300">
                <table class="table table-zebra w-full" id="admin-completed-games-table">
                  <thead>
                    <tr class="text-zinc-400 text-xs uppercase tracking-wider">
                      <th>Code PIN</th>
                      <th>Quiz</th>
                      <th>Visibilité</th>
                      <th>Participants</th>
                      <th>Vainqueur</th>
                      <th>Score Max</th>
                      <th>Terminée le</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= if @completed_games == [] do %>
                      <tr>
                        <td colspan="7" class="text-center py-10 text-zinc-400">
                          <div class="inline-flex p-3 rounded-2xl bg-base-200 text-zinc-400 mb-2">
                            <.icon name="hero-trophy" class="size-6" />
                          </div>
                          <p class="font-medium">
                            Aucune partie réalisée enregistrée pour l'instant.
                          </p>
                          <p class="text-xs text-zinc-500 mt-0.5">
                            Les parties terminées s'afficheront automatiquement ici.
                          </p>
                        </td>
                      </tr>
                    <% else %>
                      <%= for record <- @completed_games do %>
                        <tr id={"completed-game-row-#{record.id}"} class="hover">
                          <td class="font-mono text-sm font-black text-primary">{record.code}</td>
                          <td class="font-bold text-base-content">{record.quiz_title}</td>
                          <td>
                            <%= if record.visibility == "public" do %>
                              <span class="badge badge-success badge-sm text-[11px] font-bold">
                                Public
                              </span>
                            <% else %>
                              <span class="badge badge-ghost badge-sm text-[11px] font-bold text-zinc-500">
                                Privé
                              </span>
                            <% end %>
                          </td>
                          <td class="font-semibold text-sm">
                            <span class="badge badge-ghost badge-sm">
                              {record.players_count} joueurs
                            </span>
                          </td>
                          <td class="font-bold text-amber-500">
                            <%= if record.winner_name do %>
                              <span class="inline-flex items-center gap-1">
                                <.icon name="hero-trophy" class="size-3.5 text-amber-500" />
                                {record.winner_name}
                              </span>
                            <% else %>
                              <span class="text-zinc-400 italic font-normal text-xs">-</span>
                            <% end %>
                          </td>
                          <td class="font-mono font-bold text-sm">
                            {record.winner_score || 0} pts
                          </td>
                          <td class="text-xs text-zinc-500">
                            {if record.finished_at,
                              do: Calendar.strftime(record.finished_at, "%d/%m/%Y %H:%M"),
                              else: "-"}
                          </td>
                        </tr>
                      <% end %>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        <% end %>

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
                            <span class="text-zinc-600 dark:text-zinc-300">{user.email}</span>
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
                                data-confirm={
                                  "Êtes-vous sûr de vouloir supprimer définitivement le compte de #{user.username} ?"
                                }
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
                          {if is_list(quiz.questions), do: length(quiz.questions), else: 0}
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
                              data-confirm={
                                "Êtes-vous sûr de vouloir supprimer définitivement le quiz « #{quiz.title} » ?"
                              }
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

        <!-- Tab 3: Games Supervision (Active & Completed) -->
        <%= if @active_tab == "games" do %>
          <div class="space-y-6">
            <!-- Section 1: Active Games -->
            <div class="space-y-3">
              <div class="flex items-center justify-between">
                <div>
                  <h3 class="font-black text-lg text-base-content flex items-center gap-2">
                    <span class="size-2.5 rounded-full bg-emerald-500 animate-pulse"></span>
                    Parties actives en mémoire
                  </h3>
                  <p class="text-xs text-zinc-500">
                    Sessions multijoueurs actuellement gérées par l'arbre OTP
                  </p>
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
                      <th>Créateur / Hôte</th>
                      <th>Visibilité</th>
                      <th>Joueurs</th>
                      <th>Statut</th>
                      <th class="text-right">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= if @games == [] do %>
                      <tr>
                        <td colspan="7" class="text-center py-10 text-zinc-400">
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
                              <span class="font-semibold text-base-content">
                                {game.quiz.user.username}
                              </span>
                            <% else %>
                              <span class="text-zinc-400 italic">Anonyme</span>
                            <% end %>
                          </td>
                          <td>
                            <%= if to_string(game.visibility) == "public" do %>
                              <span class="badge badge-success badge-sm text-[11px] font-bold">
                                Public
                              </span>
                            <% else %>
                              <span class="badge badge-ghost badge-sm text-[11px] font-bold text-zinc-500">
                                Privé
                              </span>
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
                              data-confirm={
                                "Voulez-vous forcer l'arrêt de la partie #{game.code} ?"
                              }
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

            <!-- Section 2: Completed Games History -->
            <div class="space-y-3 pt-4 border-t border-base-200">
              <div>
                <h3 class="font-black text-lg text-base-content flex items-center gap-2">
                  <.icon name="hero-check-badge" class="size-5 text-amber-500" />
                  Historique des parties réalisées
                </h3>
                <p class="text-xs text-zinc-500">
                  Dernières parties multijoueurs terminées avec podium enregistré
                </p>
              </div>

              <div class="overflow-x-auto rounded-2xl border border-base-300 bg-base-100 shadow-sm">
                <table class="table table-zebra w-full">
                  <thead>
                    <tr class="text-zinc-400 text-xs uppercase tracking-wider">
                      <th>Code PIN</th>
                      <th>Quiz</th>
                      <th>Visibilité</th>
                      <th>Joueurs</th>
                      <th>Vainqueur</th>
                      <th>Score</th>
                      <th>Date</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= if @completed_games == [] do %>
                      <tr>
                        <td colspan="7" class="text-center py-8 text-zinc-400">
                          Aucune partie réalisée enregistrée pour l'instant.
                        </td>
                      </tr>
                    <% else %>
                      <%= for record <- @completed_games do %>
                        <tr class="hover">
                          <td class="font-mono text-sm font-black text-primary">{record.code}</td>
                          <td class="font-bold">{record.quiz_title}</td>
                          <td>
                            <%= if record.visibility == "public" do %>
                              <span class="badge badge-success badge-sm text-[11px] font-bold">
                                Public
                              </span>
                            <% else %>
                              <span class="badge badge-ghost badge-sm text-[11px] font-bold text-zinc-500">
                                Privé
                              </span>
                            <% end %>
                          </td>
                          <td class="font-semibold text-sm">
                            {record.players_count} joueurs
                          </td>
                          <td class="font-bold text-amber-500">
                            {record.winner_name || "-"}
                          </td>
                          <td class="font-mono font-bold text-sm">
                            {record.winner_score || 0} pts
                          </td>
                          <td class="text-xs text-zinc-500">
                            {if record.finished_at,
                              do: Calendar.strftime(record.finished_at, "%d/%m/%Y %H:%M"),
                              else: "-"}
                          </td>
                        </tr>
                      <% end %>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
