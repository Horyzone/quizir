defmodule QuizirWeb.HomeLive do
  use QuizirWeb, :live_view

  alias Quizir.Games
  alias Quizir.Quizzes

  @impl true
  def mount(_params, _session, socket) do
    all_quizzes = Quizzes.list_quizzes()
    recent_quizzes = Enum.filter(all_quizzes, &(&1.visibility == "public")) |> Enum.take(4)

    default_nickname =
      if socket.assigns[:current_user], do: socket.assigns.current_user.username, else: ""

    join_form =
      to_form(
        %{"pin" => "", "nickname" => default_nickname},
        as: "quick_join"
      )

    {:ok,
     socket
     |> assign(:page_title, "Accueil - Quizir")
     |> assign(:recent_quizzes, recent_quizzes)
     |> assign(:total_quizzes_count, length(all_quizzes))
     |> assign(:join_form, join_form)
     |> assign(:join_error, nil)}
  end

  @impl true
  def handle_event("validate_quick_join", %{"quick_join" => params}, socket) do
    clean_pin = String.upcase(String.trim(params["pin"] || ""))

    form =
      to_form(
        %{"pin" => clean_pin, "nickname" => params["nickname"] || ""},
        as: "quick_join"
      )

    {:noreply, assign(socket, join_form: form, join_error: nil)}
  end

  @impl true
  def handle_event(
        "quick_join",
        %{"quick_join" => %{"pin" => pin, "nickname" => nickname}},
        socket
      ) do
    clean_pin = String.upcase(String.trim(pin || ""))
    clean_nickname = String.trim(nickname || "")

    cond do
      clean_pin == "" ->
        {:noreply, assign(socket, :join_error, "Veuillez entrer le code PIN du salon.")}

      clean_nickname == "" ->
        {:noreply, assign(socket, :join_error, "Veuillez entrer votre pseudo.")}

      not Games.game_exists?(clean_pin) ->
        {:noreply,
         assign(socket, :join_error, "Ce salon de jeu n'existe pas ou la partie est terminée.")}

      true ->
        case Games.join_game(clean_pin, clean_nickname) do
          {:ok, player} ->
            {:noreply,
             socket
             |> put_flash(:info, "Bienvenue #{player.name} dans la partie !")
             |> push_navigate(
               to: ~p"/games/#{clean_pin}?player_id=#{player.id}&name=#{URI.encode(player.name)}"
             )}

          {:error, :game_already_started} ->
            {:noreply,
             assign(socket, :join_error, "La partie a déjà commencé. Impossible de rejoindre.")}

          {:error, :invalid_name} ->
            {:noreply, assign(socket, :join_error, "Pseudo invalide.")}

          {:error, _} ->
            {:noreply, assign(socket, :join_error, "Impossible de rejoindre ce salon.")}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      container_class="mx-auto max-w-5xl space-y-20 py-4"
    >
      <!-- 1. Hero Section -->
      <section class="relative pt-6 sm:pt-12 text-center lg:text-left">
        <div class="grid grid-cols-1 lg:grid-cols-12 gap-12 items-center">
          <div class="lg:col-span-7 space-y-6">
            <img src={~p"/images/logo.svg"} alt="Quizir Logo" class="mx-auto lg:mx-0" />

            <h1 class="text-4xl sm:text-5xl lg:text-6xl font-black tracking-tight text-base-content leading-[1.1]">
              Défiez vos amis avec des <span class="text-primary underline decoration-primary/30 decoration-wavy">quiz en direct</span>.
            </h1>

            <p class="text-lg sm:text-xl text-base-content/70 max-w-xl mx-auto lg:mx-0 font-normal leading-relaxed">
              Créez vos questionnaires personnalisés, projetez les questions et faites vibrer vos participants avec des classements et duels instantanés.
            </p>

            <!-- Actions principales -->
            <div class="flex flex-wrap items-center justify-center lg:justify-start gap-4 pt-2">
              <%= if @current_scope && @current_scope.user do %>
                <.link
                  id="hero-create-quiz-btn"
                  navigate={~p"/quizzes/new"}
                  class="btn btn-primary btn-lg font-bold gap-2 shadow-xl shadow-primary/25 hover:shadow-primary/40 hover:scale-105 transition"
                >
                  <.icon name="hero-plus-circle" class="size-6" /> Créer un quiz
                </.link>
                <.link
                  id="hero-explore-quizzes-btn"
                  navigate={~p"/quizzes"}
                  class="btn btn-outline btn-lg font-bold gap-2 hover:bg-base-200"
                >
                  <.icon name="hero-rectangle-stack" class="size-5" /> Explorer les quiz
                </.link>
              <% else %>
                <.link
                  id="hero-join-game-btn"
                  navigate={~p"/join"}
                  class="btn btn-primary btn-lg font-bold gap-2 shadow-xl shadow-primary/25 hover:shadow-primary/40 hover:scale-105 transition"
                >
                  <.icon name="hero-play" class="size-6" /> Rejoindre avec un PIN
                </.link>
                <.link
                  id="hero-register-btn"
                  navigate={~p"/users/register"}
                  class="btn btn-outline btn-lg font-bold gap-2 hover:bg-base-200"
                >
                  <.icon name="hero-user-plus" class="size-5" /> Inscription gratuite
                </.link>
              <% end %>
            </div>

            <!-- Stats rapides -->
            <div class="flex items-center justify-center lg:justify-start gap-8 pt-6 border-t border-base-200 text-sm text-base-content/60">
              <div class="flex items-center gap-2">
                <.icon name="hero-bolt" class="size-5 text-warning" />
                <span>0 ms de latence (OTP)</span>
              </div>
              <div class="flex items-center gap-2">
                <.icon name="hero-check-badge" class="size-5 text-success" />
                <span>Gratuit & sans pub</span>
              </div>
              <div class="flex items-center gap-2">
                <.icon name="hero-device-phone-mobile" class="size-5 text-primary" />
                <span>Tous smartphones</span>
              </div>
            </div>
          </div>

          <!-- Quick Join Box Card -->
          <div class="lg:col-span-5">
            <div class="p-8 rounded-3xl bg-base-100 border border-base-300 shadow-2xl relative overflow-hidden">
              <div class="absolute -right-8 -top-8 size-32 bg-primary/10 rounded-full blur-2xl pointer-events-none">
              </div>

              <div class="flex items-center gap-3 mb-6">
                <div class="size-10 rounded-2xl bg-primary text-primary-content flex items-center justify-center shadow-md shadow-primary/30 font-black">
                  <.icon name="hero-play" class="size-5" />
                </div>
                <div>
                  <h3 class="text-xl font-bold">Rejoindre une partie</h3>
                  <p class="text-xs text-base-content/60">Entrez le code PIN affiché par l'hôte</p>
                </div>
              </div>

              <div :if={@join_error} id="quick-join-error" class="alert alert-error text-xs mb-4">
                <.icon name="hero-exclamation-triangle" class="size-4 shrink-0" />
                <span>{@join_error}</span>
              </div>

              <.form
                for={@join_form}
                id="quick-join-form"
                phx-change="validate_quick_join"
                phx-submit="quick_join"
                class="space-y-4"
              >
                <div>
                  <.input
                    field={@join_form[:pin]}
                    id="quick-join-pin"
                    placeholder="Code PIN"
                    phx-hook=".HomePinMask"
                    class="input input-lg w-full text-center font-mono font-black tracking-widest text-2xl uppercase"
                    required
                  />
                </div>

                <div>
                  <.input
                    field={@join_form[:nickname]}
                    id="quick-join-nickname"
                    placeholder="Votre pseudo"
                    class="input input-lg w-full text-center font-semibold"
                    maxlength="20"
                    required
                  />
                </div>

                <.button
                  id="quick-join-submit-btn"
                  variant="primary"
                  class="btn btn-primary btn-lg w-full font-bold shadow-lg shadow-primary/25"
                >
                  Entrer dans l'arène <.icon name="hero-arrow-right" class="size-5 ml-1" />
                </.button>
              </.form>
            </div>
          </div>
        </div>
      </section>

      <!-- 2. Interactive Game Simulation Preview -->
      <section class="space-y-4">
        <div class="text-center max-w-xl mx-auto mb-8">
          <span class="badge badge-primary badge-sm uppercase font-bold tracking-widest mb-2">Expérience en direct</span>
          <h2 class="text-3xl font-extrabold">Une interface captivante</h2>
          <p class="text-sm text-base-content/60 mt-1">
            Questions chronométrées, bonus de réactivité et suspense garanti jusqu'au podium.
          </p>
        </div>

        <div class="p-6 sm:p-8 rounded-3xl bg-base-100 border border-base-300 shadow-xl max-w-3xl mx-auto space-y-6">
          <!-- Top bar preview -->
          <div class="flex items-center justify-between pb-4 border-b border-base-200 text-sm">
            <span class="badge badge-neutral font-semibold">Question 3 / 5</span>
            <div class="badge badge-error gap-1.5 font-mono font-black text-sm px-3 py-3 animate-pulse">
              <.icon name="hero-clock" class="size-4" /> 14s
            </div>
          </div>

          <!-- Question Body Preview -->
          <h3 class="text-xl sm:text-2xl font-bold text-center py-2 text-base-content">
            En quelle année le premier homme a-t-il marché sur la Lune ?
          </h3>

          <!-- Options Grid Preview -->
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div class="p-4 rounded-2xl bg-rose-500 text-white font-bold flex items-center justify-between shadow-sm">
              <span>1965</span>
              <span class="size-7 rounded-full bg-white/20 flex items-center justify-center text-xs">A</span>
            </div>
            <div class="p-4 rounded-2xl bg-blue-500 text-white font-bold flex items-center justify-between shadow-md ring-4 ring-blue-300">
              <span>1969 (Apollo 11)</span>
              <span class="badge badge-sm badge-success font-bold gap-1">
                <.icon name="hero-check" class="size-3" /> Correct
              </span>
            </div>
            <div class="p-4 rounded-2xl bg-amber-500 text-white font-bold flex items-center justify-between shadow-sm">
              <span>1972</span>
              <span class="size-7 rounded-full bg-white/20 flex items-center justify-center text-xs">C</span>
            </div>
            <div class="p-4 rounded-2xl bg-emerald-500 text-white font-bold flex items-center justify-between shadow-sm">
              <span>1961</span>
              <span class="size-7 rounded-full bg-white/20 flex items-center justify-center text-xs">D</span>
            </div>
          </div>

          <!-- Score & Streak preview banner -->
          <div class="p-3 rounded-2xl bg-base-200 flex items-center justify-between text-xs sm:text-sm font-semibold">
            <div class="flex items-center gap-2">
              <span class="badge badge-warning badge-sm gap-1 font-bold">🔥 Combo x3</span>
              <span class="text-base-content/80">+890 pts (Bonus vitesse inclus)</span>
            </div>
            <span class="badge badge-neutral font-mono font-bold">Rang #1</span>
          </div>
        </div>
      </section>

      <!-- 3. How it Works (3 steps) -->
      <section class="space-y-8">
        <div class="text-center max-w-xl mx-auto">
          <span class="badge badge-neutral badge-sm uppercase font-bold tracking-widest mb-2">Simplicité absolue</span>
          <h2 class="text-3xl font-extrabold">Comment lancer votre partie en 3 étapes</h2>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div class="p-6 rounded-3xl bg-base-100 border border-base-300 shadow-sm space-y-4 hover:border-primary/50 transition">
            <div class="size-12 rounded-2xl bg-primary/10 text-primary flex items-center justify-center font-black text-xl">
              1
            </div>
            <h3 class="text-lg font-bold">Créez votre Quiz</h3>
            <p class="text-sm text-base-content/70">
              Rédigez vos questions, définissez les limites de temps et choisissez une visibilité publique ou privée avec code d'accès.
            </p>
          </div>

          <div class="p-6 rounded-3xl bg-base-100 border border-base-300 shadow-sm space-y-4 hover:border-primary/50 transition">
            <div class="size-12 rounded-2xl bg-secondary/10 text-secondary flex items-center justify-center font-black text-xl">
              2
            </div>
            <h3 class="text-lg font-bold">Partagez le code PIN</h3>
            <p class="text-sm text-base-content/70">
              Affichez l'écran sur projecteur ou écran partagé. Vos joueurs rejoignent depuis leur navigateur mobile sans téléchargement.
            </p>
          </div>

          <div class="p-6 rounded-3xl bg-base-100 border border-base-300 shadow-sm space-y-4 hover:border-primary/50 transition">
            <div class="size-12 rounded-2xl bg-accent/10 text-accent flex items-center justify-center font-black text-xl">
              3
            </div>
            <h3 class="text-lg font-bold">Jouez & gagnez</h3>
            <p class="text-sm text-base-content/70">
              L'hôte peut participer au jeu comme n'importe quel joueur. Les scores sont mis à jour en temps réel jusqu'au podium final !
            </p>
          </div>
        </div>
      </section>

      <!-- 4. Featured Quizzes Section -->
      <section class="space-y-6">
        <div class="flex items-center justify-between">
          <div>
            <h2 class="text-2xl sm:text-3xl font-bold">Quiz publics à découvrir</h2>
            <p class="text-sm text-base-content/60">
              Lancez une partie immédiate ou dupliquez pour personnaliser
            </p>
          </div>

          <.link navigate={~p"/quizzes"} class="btn btn-ghost btn-sm font-semibold gap-1">
            Tout voir ({length(@recent_quizzes)}) <.icon name="hero-arrow-right" class="size-4" />
          </.link>
        </div>

        <%= if Enum.empty?(@recent_quizzes) do %>
          <div class="p-8 rounded-3xl bg-base-100 border border-base-300 text-center space-y-3">
            <div class="inline-flex p-3 rounded-2xl bg-base-200 text-base-content/50">
              <.icon name="hero-folder-open" class="size-8" />
            </div>
            <h4 class="text-lg font-bold">Aucun quiz public pour l'instant</h4>
            <p class="text-sm text-base-content/60 max-w-md mx-auto">
              Soyez le premier à partager votre savoir en créant un quiz ouvert à tous !
            </p>
            <.link navigate={~p"/quizzes/new"} class="btn btn-primary btn-sm font-bold">
              Créer le premier quiz
            </.link>
          </div>
        <% else %>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <%= for quiz <- @recent_quizzes do %>
              <div
                id={"featured-quiz-#{quiz.id}"}
                class="p-5 rounded-2xl bg-base-100 border border-base-300 shadow-sm hover:border-primary/40 transition flex flex-col justify-between space-y-4"
              >
                <div>
                  <div class="flex items-start justify-between gap-2">
                    <h4 class="font-bold text-lg text-base-content hover:text-primary transition line-clamp-1">
                      {quiz.title}
                    </h4>
                    <span class="badge badge-success badge-sm font-semibold shrink-0">Public</span>
                  </div>

                  <p class="text-xs text-base-content/60 line-clamp-2 mt-1">
                    {quiz.description || "Aucune description fournie."}
                  </p>

                  <%= if quiz.user do %>
                    <p class="text-xs text-base-content/50 mt-2 flex items-center gap-1">
                      <.icon name="hero-user" class="size-3" /> par
                      <span class="font-semibold text-base-content/80">{quiz.user.username}</span>
                    </p>
                  <% end %>
                </div>

                <div class="pt-3 border-t border-base-200 flex items-center justify-between">
                  <.link
                    navigate={~p"/quizzes/#{quiz}"}
                    class="btn btn-xs btn-primary gap-1 font-semibold"
                  >
                    <.icon name="hero-play" class="size-3" /> Jouer / Détails
                  </.link>

                  <.link
                    navigate={~p"/quizzes/#{quiz}"}
                    class="btn btn-xs btn-ghost text-xs gap-1 text-base-content/60 hover:text-base-content"
                  >
                    <.icon name="hero-document-duplicate" class="size-3" /> Dupliquer
                  </.link>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </section>

      <!-- 5. Key Features Highlights -->
      <section class="p-8 sm:p-12 rounded-3xl bg-base-200 border border-base-300 space-y-8">
        <div class="text-center max-w-lg mx-auto">
          <h2 class="text-2xl sm:text-3xl font-extrabold">Pourquoi choisir Quizir ?</h2>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6 text-center">
          <div class="space-y-2">
            <div class="size-12 mx-auto rounded-2xl bg-base-100 flex items-center justify-center text-primary shadow-xs">
              <.icon name="hero-bolt" class="size-6" />
            </div>
            <h4 class="font-bold text-base">Temps réel</h4>
            <p class="text-xs text-base-content/60">
              Chaque partie est isolée des autres et instantanée.
            </p>
          </div>

          <div class="space-y-2">
            <div class="size-12 mx-auto rounded-2xl bg-base-100 flex items-center justify-center text-secondary shadow-xs">
              <.icon name="hero-user-group" class="size-6" />
            </div>
            <h4 class="font-bold text-base">Hôte participant</h4>
            <p class="text-xs text-base-content/60">
              L'organisateur peut animer et répondre aux questions comme n'importe quel joueur.
            </p>
          </div>

          <div class="space-y-2">
            <div class="size-12 mx-auto rounded-2xl bg-base-100 flex items-center justify-center text-accent shadow-xs">
              <.icon name="hero-document-duplicate" class="size-6" />
            </div>
            <h4 class="font-bold text-base">Duplication en 1 clic</h4>
            <p class="text-xs text-base-content/60">
              Clonez n'importe quel quiz public sur votre compte pour l'adapter à vos envies.
            </p>
          </div>

          <div class="space-y-2">
            <div class="size-12 mx-auto rounded-2xl bg-base-100 flex items-center justify-center text-success shadow-xs">
              <.icon name="hero-shield-check" class="size-6" />
            </div>
            <h4 class="font-bold text-base">Anti-triche natif</h4>
            <p class="text-xs text-base-content/60">
              Les bonnes réponses sont masquées dans le flux websocket jusqu'au décompte final.
            </p>
          </div>
        </div>
      </section>

      <!-- 6. Bottom Call to Action -->
      <section class="text-center py-8 space-y-6">
        <h2 class="text-3xl sm:text-4xl font-black">Prêt à enflammer votre prochain événement ?</h2>
        <p class="text-base text-base-content/70 max-w-md mx-auto">
          Rejoignez Quizir gratuitement en quelques secondes et lancez votre première partie.
        </p>

        <div class="flex flex-wrap items-center justify-center gap-4">
          <%= if @current_scope && @current_scope.user do %>
            <.link navigate={~p"/quizzes/new"} class="btn btn-primary btn-lg font-bold gap-2">
              <.icon name="hero-plus-circle" class="size-5" /> Créer un Quiz maintenant
            </.link>
          <% else %>
            <.link navigate={~p"/users/register"} class="btn btn-primary btn-lg font-bold gap-2">
              <.icon name="hero-user-plus" class="size-5" /> Créer un compte gratuit
            </.link>
            <.link navigate={~p"/join"} class="btn btn-outline btn-lg font-bold gap-2">
              <.icon name="hero-play" class="size-5" /> Rejoindre avec un PIN
            </.link>
          <% end %>
        </div>
      </section>

      <!-- 7. Footer -->
      <footer class="pt-12 pb-6 border-t border-base-200 text-xs text-base-content/50 flex flex-col sm:flex-row items-center justify-between gap-4">
        <div class="flex items-center gap-2 font-bold text-base text-base-content">
          <img src={~p"/images/logo.svg"} width="24" height="24" alt="Quizir" class="rounded-md" />
          <span>Quizir</span>
        </div>
        <div class="flex items-center gap-6 flex-wrap">
          <.link navigate={~p"/quizzes"} class="hover:underline">Quiz disponibles</.link>
          <.link navigate={~p"/join"} class="hover:underline">Rejoindre une partie</.link>
          <%= if @current_scope && @current_scope.user do %>
            <.link navigate={~p"/my-quizzes"} class="hover:underline">Mes quiz</.link>
            <.link navigate={~p"/users/settings"} class="hover:underline">Mon compte</.link>
            <.link navigate={~p"/quizzes/new"} class="hover:underline">Créer un quiz</.link>
          <% else %>
            <.link navigate={~p"/users/log_in"} class="hover:underline">Connexion</.link>
            <.link navigate={~p"/users/register"} class="hover:underline">Inscription</.link>
          <% end %>
        </div>
        <p>© 2026 Quizir. Tous droits réservés.</p>
      </footer>
    </Layouts.app>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".HomePinMask">
      export default {
        mounted() {
          this.el.addEventListener("input", e => {
            this.el.value = this.el.value.toUpperCase().replace(/[^A-Z0-9]/g, "")
          })
        }
      }
    </script>
    """
  end
end
