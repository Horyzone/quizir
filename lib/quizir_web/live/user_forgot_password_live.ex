defmodule QuizirWeb.UserForgotPasswordLive do
  use QuizirWeb, :live_view

  alias Quizir.Accounts

  @impl true
  def mount(_params, _session, socket) do
    form = to_form(%{"identifier" => ""}, as: "user")
    {:ok, assign(socket, form: form, sent: false, page_title: "Mot de passe oublié")}
  end

  @impl true
  def handle_event("send_instructions", %{"user" => %{"identifier" => identifier}}, socket) do
    Accounts.deliver_user_reset_password_instructions(identifier, fn token ->
      url(~p"/users/reset_password/#{token}")
    end)

    {:noreply, assign(socket, :sent, true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-md mx-auto py-8">
        <div class="text-center mb-8">
          <div class="inline-flex p-3 rounded-2xl bg-primary/10 text-primary mb-3">
            <.icon name="hero-key" class="size-8" />
          </div>
          <h1 class="text-3xl font-extrabold tracking-tight">Mot de passe oublié</h1>
          <p class="text-sm text-zinc-500 mt-2">
            Entrez votre nom d'utilisateur ou votre adresse email pour recevoir un lien de réinitialisation.
          </p>
        </div>

        <div class="p-8 rounded-3xl bg-base-100 border border-base-300 shadow-xl">
          <%= if @sent do %>
            <div id="reset-instructions-sent" class="text-center space-y-4">
              <div class="inline-flex p-3 rounded-full bg-success/10 text-success">
                <.icon name="hero-envelope-open" class="size-8" />
              </div>
              <h3 class="text-lg font-bold">Vérifiez votre boîte de réception</h3>
              <p class="text-sm text-zinc-600">
                Si un compte avec une adresse email correspond aux informations renseignées, vous recevrez un lien de réinitialisation d'ici quelques instants.
              </p>
              <div class="pt-4">
                <.link navigate={~p"/users/log_in"} class="btn btn-primary w-full">
                  Retour à la connexion
                </.link>
              </div>
            </div>
          <% else %>
            <.form
              for={@form}
              id="forgot_password_form"
              phx-submit="send_instructions"
              class="space-y-4"
            >
              <.input
                field={@form[:identifier]}
                type="text"
                label="Nom d'utilisateur ou Email"
                id="reset_identifier"
                placeholder="Votre pseudo ou email..."
                required
              />

              <div class="pt-2">
                <.button
                  id="forgot-password-submit-btn"
                  variant="primary"
                  phx-disable-with="Envoi en cours..."
                  class="btn btn-primary btn-lg w-full font-bold shadow-md shadow-primary/20"
                >
                  Envoyer le lien <.icon name="hero-paper-airplane" class="size-5 ml-1" />
                </.button>
              </div>
            </.form>
          <% end %>
        </div>

        <div class="text-center mt-6 text-sm text-zinc-500">
          <.link navigate={~p"/users/log_in"} class="font-bold text-primary hover:underline">
            <.icon name="hero-arrow-left" class="size-4 inline mr-1" /> Retour à la connexion
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
