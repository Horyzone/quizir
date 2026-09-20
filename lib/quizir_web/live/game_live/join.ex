defmodule QuizirWeb.GameLive.Join do
  use QuizirWeb, :live_view

  alias Quizir.Games

  @impl true
  def mount(params, _session, socket) do
    default_nickname =
      cond do
        params["nickname"] && params["nickname"] != "" -> params["nickname"]
        socket.assigns[:current_user] -> socket.assigns.current_user.username
        true -> ""
      end

    form =
      to_form(%{
        "pin" => params["pin"] || "",
        "nickname" => default_nickname
      })

    public_games = Games.list_active_public_games()

    {:ok,
     socket
     |> assign(:page_title, "Rejoindre une partie")
     |> assign(:form, form)
     |> assign(:public_games, public_games)
     |> assign(:error_message, nil)}
  end

  @impl true
  def handle_event("validate", %{"pin" => pin, "nickname" => nickname}, socket) do
    form =
      to_form(%{
        "pin" => String.upcase(String.trim(pin)),
        "nickname" => nickname
      })

    {:noreply, assign(socket, form: form, error_message: nil)}
  end

  @impl true
  def handle_event("join", %{"pin" => pin, "nickname" => nickname}, socket) do
    clean_pin = String.upcase(String.trim(pin || ""))
    clean_nickname = String.trim(nickname || "")

    cond do
      clean_pin == "" ->
        {:noreply, assign(socket, :error_message, "Veuillez saisir le code PIN du salon.")}

      clean_nickname == "" ->
        {:noreply, assign(socket, :error_message, "Veuillez choisir un pseudo.")}

      not Games.game_exists?(clean_pin) ->
        {:noreply,
         assign(socket, :error_message, "Ce salon de jeu n'existe pas ou la partie est terminée.")}

      true ->
        case Games.join_game(clean_pin, clean_nickname) do
          {:ok, player} ->
            {:noreply,
             socket
             |> put_flash(:info, "Bienvenue #{player.name} !")
             |> push_navigate(
               to: ~p"/games/#{clean_pin}?player_id=#{player.id}&name=#{URI.encode(player.name)}"
             )}

          {:error, :game_already_started} ->
            {:noreply,
             assign(
               socket,
               :error_message,
               "La partie a déjà commencé. Impossible de rejoindre en cours de jeu."
             )}

          {:error, :invalid_name} ->
            {:noreply, assign(socket, :error_message, "Pseudo invalide.")}

          {:error, _} ->
            {:noreply,
             assign(
               socket,
               :error_message,
               "Impossible de rejoindre ce salon. Réessayez."
             )}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto py-8 px-4 sm:px-6">
        <div class="text-center mb-8">
          <div class="inline-flex items-center justify-center p-3 mb-3 rounded-2xl bg-primary/10 text-primary">
            <.icon name="hero-play" class="size-8" />
          </div>
          <h1 class="text-3xl font-extrabold tracking-tight">Rejoindre une Partie</h1>
          <p class="text-sm text-base-content/60 mt-2">
            Entrez un code PIN pour rejoindre un salon privé, ou participez à une partie publique en cours !
          </p>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-8 items-start">
          <!-- 1. Formulaire PIN Privé -->
          <div class="p-6 sm:p-8 rounded-3xl bg-base-100 border border-base-300 shadow-xl">
            <div class="flex items-center gap-2 mb-4">
              <div class="p-2 rounded-xl bg-amber-500/10 text-amber-600">
                <.icon name="hero-lock-closed" class="size-5" />
              </div>
              <h2 class="text-lg font-bold">Salon privé (Code PIN)</h2>
            </div>

            <div :if={@error_message} id="join-error-alert" class="alert alert-error mb-6 text-sm">
              <.icon name="hero-exclamation-triangle" class="size-5 shrink-0" />
              <span>{@error_message}</span>
            </div>

            <.form
              for={@form}
              id="join-game-form"
              phx-change="validate"
              phx-submit="join"
              class="space-y-5"
            >
              <div>
                <.input
                  field={@form[:pin]}
                  id="join-pin-input"
                  label="Code PIN du salon"
                  placeholder="Ex: AB4821"
                  phx-hook=".PinMask"
                  class="input input-lg w-full text-center font-mono font-bold tracking-widest uppercase text-xl"
                  required
                />
              </div>

              <div>
                <.input
                  field={@form[:nickname]}
                  id="join-nickname-input"
                  label="Votre pseudo"
                  placeholder="Ex: ChampionDuQuiz"
                  class="input input-lg w-full text-center font-semibold"
                  maxlength="20"
                  required
                />
              </div>

              <.button
                id="submit-join-btn"
                variant="primary"
                class="btn btn-primary btn-lg w-full font-bold shadow-lg shadow-primary/20 hover:shadow-primary/40 mt-4"
              >
                Rejoindre le salon <.icon name="hero-arrow-right" class="size-5 ml-1" />
              </.button>
            </.form>
          </div>

          <!-- 2. Parties Publiques en cours -->
          <div class="p-6 sm:p-8 rounded-3xl bg-base-100 border border-base-300 shadow-sm flex flex-col h-full justify-between">
            <div>
              <div class="flex items-center justify-between gap-2 mb-4">
                <div class="flex items-center gap-2">
                  <div class="p-2 rounded-xl bg-emerald-500/10 text-emerald-600">
                    <.icon name="hero-globe-alt" class="size-5" />
                  </div>
                  <h2 class="text-lg font-bold">Parties publiques en cours</h2>
                </div>
                <span class="badge badge-success badge-sm font-semibold text-white">
                  {length(@public_games)} en direct
                </span>
              </div>

              <p class="text-xs text-base-content/60 mb-6 leading-relaxed">
                Les sessions publiques sont ouvertes à tous sans avoir besoin de code PIN. Cliquez pour entrer directement dans la partie !
              </p>

              <%= if @public_games == [] do %>
                <div class="text-center py-8 px-4 border border-dashed border-base-300 rounded-2xl bg-base-200/50">
                  <.icon name="hero-puzzle-piece" class="size-8 mx-auto text-base-content/40 mb-2" />
                  <p class="text-sm font-semibold text-base-content/70">
                    Aucune partie publique en attente
                  </p>
                  <p class="text-xs text-base-content/50 mt-1 mb-4">
                    Soyez le premier à lancer une session ouverte à toute la communauté !
                  </p>
                  <.link navigate={~p"/quizzes"} class="btn btn-sm btn-outline font-bold">
                    Choisir un quiz à lancer
                  </.link>
                </div>
              <% else %>
                <div class="space-y-3 max-h-[350px] overflow-y-auto pr-1">
                  <div
                    :for={game <- @public_games}
                    class="p-4 rounded-2xl border border-base-200 hover:border-primary/50 bg-base-200/30 transition flex items-center justify-between gap-3"
                  >
                    <div class="min-w-0 flex-1">
                      <div class="flex items-center gap-2">
                        <span class="size-2 rounded-full bg-emerald-500 animate-pulse"></span>
                        <h3 class="font-bold text-sm truncate">{game.quiz.title}</h3>
                      </div>
                      <p class="text-xs text-base-content/60 mt-1 flex items-center gap-3">
                        <span class="inline-flex items-center gap-1">
                          <.icon name="hero-users" class="size-3.5 text-primary" />
                          {length(Map.keys(game.players || %{}))} joueur{if length(
                                                                              Map.keys(
                                                                                game.players || %{}
                                                                              )
                                                                            ) > 1,
                                                                            do: "s",
                                                                            else: ""}
                        </span>
                        <span class="inline-flex items-center gap-1">
                          <.icon name="hero-question-mark-circle" class="size-3.5" />
                          {length(game.questions || [])} questions
                        </span>
                      </p>
                    </div>

                    <.link
                      navigate={~p"/games/#{game.code}"}
                      id={"join-public-game-#{game.code}-btn"}
                      class="btn btn-primary btn-sm font-bold shrink-0 gap-1"
                    >
                      Rejoindre <.icon name="hero-arrow-right" class="size-3.5" />
                    </.link>
                  </div>
                </div>
              <% end %>
            </div>

            <div class="mt-6 pt-4 border-t border-base-200 flex items-center justify-between text-xs text-base-content/60">
              <.link
                navigate={~p"/games"}
                class="hover:underline font-semibold flex items-center gap-1"
              >
                <.icon name="hero-arrow-top-right-on-square" class="size-3.5" />
                Voir toutes les parties en cours
              </.link>
              <.link navigate={~p"/quizzes"} class="hover:underline">
                Quiz disponibles
              </.link>
            </div>
          </div>
        </div>
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".PinMask">
        export default {
          mounted() {
            this.el.addEventListener("input", e => {
              this.el.value = this.el.value.toUpperCase().replace(/[^A-Z0-9]/g, "")
            })
          }
        }
      </script>
    </Layouts.app>
    """
  end
end
