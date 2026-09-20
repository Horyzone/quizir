defmodule QuizirWeb.GameLive.Join do
  use QuizirWeb, :live_view

  alias Quizir.Games

  @impl true
  def mount(params, _session, socket) do
    form =
      to_form(%{
        "pin" => params["pin"] || "",
        "nickname" => "",
        "access_code" => ""
      })

    {:ok,
     socket
     |> assign(:page_title, "Rejoindre une partie")
     |> assign(:form, form)
     |> assign(:error_message, nil)}
  end

  @impl true
  def handle_event("validate", %{"pin" => pin, "nickname" => nickname} = params, socket) do
    form =
      to_form(%{
        "pin" => String.upcase(String.trim(pin)),
        "nickname" => nickname,
        "access_code" => params["access_code"] || ""
      })

    {:noreply, assign(socket, form: form, error_message: nil)}
  end

  @impl true
  def handle_event("join", %{"pin" => pin, "nickname" => nickname} = params, socket) do
    clean_pin = String.upcase(String.trim(pin || ""))
    clean_nickname = String.trim(nickname || "")
    access_code = String.trim(params["access_code"] || "")

    cond do
      clean_pin == "" ->
        {:noreply, assign(socket, :error_message, "Veuillez saisir le code PIN du salon.")}

      clean_nickname == "" ->
        {:noreply, assign(socket, :error_message, "Veuillez choisir un pseudo.")}

      not Games.game_exists?(clean_pin) ->
        {:noreply,
         assign(socket, :error_message, "Ce salon de jeu n'existe pas ou la partie est terminée.")}

      true ->
        case Games.join_game(clean_pin, clean_nickname, access_code: access_code) do
          {:ok, player} ->
            {:noreply,
             socket
             |> put_flash(:info, "Bienvenue #{player.name} !")
             |> push_navigate(
               to: ~p"/games/#{clean_pin}?player_id=#{player.id}&name=#{URI.encode(player.name)}"
             )}

          {:error, :invalid_access_code} ->
            {:noreply,
             assign(
               socket,
               :error_message,
               "Code d'accès incorrect pour ce quiz privé."
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
    <Layouts.app flash={@flash}>
      <div class="max-w-md mx-auto py-8">
        <div class="text-center mb-8">
          <div class="inline-flex items-center justify-center p-3 mb-4 rounded-2xl bg-primary/10 text-primary">
            <.icon name="hero-play" class="size-8" />
          </div>
          <h1 class="text-3xl font-extrabold tracking-tight">Rejoindre un Quiz</h1>
          <p class="text-sm text-zinc-500 mt-2">
            Entrez le code PIN du salon et votre pseudo pour participer en direct !
          </p>
        </div>

        <div class="p-6 sm:p-8 rounded-3xl bg-base-100 border border-base-300 shadow-xl">
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

            <div>
              <.input
                field={@form[:access_code]}
                id="join-access-code-input"
                label="Code d'accès (si quiz privé)"
                placeholder="Optionnel sauf si requis"
                class="input w-full text-center font-mono"
              />
            </div>

            <.button
              id="submit-join-btn"
              variant="primary"
              class="btn btn-primary btn-lg w-full font-bold shadow-lg shadow-primary/20 hover:shadow-primary/40 mt-4"
            >
              Rejoindre la partie <.icon name="hero-arrow-right" class="size-5 ml-1" />
            </.button>
          </.form>
        </div>

        <div class="text-center mt-6">
          <.link
            navigate={~p"/quizzes"}
            class="text-sm text-zinc-500 hover:text-primary transition inline-flex items-center gap-1"
          >
            <.icon name="hero-arrow-left" class="size-4" /> Retourner aux quiz
          </.link>
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
