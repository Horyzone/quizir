defmodule QuizirWeb.UserTwoFactorLive do
  use QuizirWeb, :live_view

  alias Quizir.Accounts

  @impl true
  def mount(_params, session, socket) do
    user_id = session["totp_auth_user_id"]
    user = user_id && Accounts.get_user(user_id)

    if user && user.totp_enabled do
      form = to_form(%{"code" => ""}, as: "totp")

      {:ok,
       socket
       |> assign(:page_title, "Authentification à deux facteurs")
       |> assign(:username, user.username)
       |> assign(:form, form), temporary_assigns: [form: form]}
    else
      {:ok, redirect(socket, to: ~p"/users/log_in")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-md mx-auto py-8">
        <div class="text-center mb-8">
          <div class="inline-flex p-3.5 rounded-2xl bg-primary/10 text-primary mb-3 shadow-inner ring-1 ring-primary/20">
            <.icon name="hero-shield-check" class="size-8" />
          </div>
          <h1 class="text-3xl font-extrabold tracking-tight">Vérification 2FA</h1>
          <p class="text-sm text-zinc-500 mt-2">
            Entrez le code à 6 chiffres généré par votre application d'authentification pour <span class="font-bold text-base-content">{@username}</span>.
          </p>
        </div>

        <div class="p-8 rounded-3xl bg-base-100 border border-base-300 shadow-xl">
          <.form
            for={@form}
            id="two_factor_form"
            action={~p"/users/two_factor"}
            phx-update="ignore"
            class="space-y-5"
          >
            <.input
              field={@form[:code]}
              type="text"
              label="Code d'authentification"
              id="totp_code"
              placeholder="000000"
              maxlength="8"
              autocomplete="one-time-code"
              inputmode="numeric"
              pattern="[0-9]*"
              class="text-center text-2xl font-mono tracking-widest"
              required
              autofocus
            />

            <div class="pt-2">
              <.button
                id="totp-submit-btn"
                variant="primary"
                class="btn btn-primary btn-lg w-full font-bold shadow-md shadow-primary/20 gap-2"
              >
                <.icon name="hero-check" class="size-5" /> Vérifier et continuer
              </.button>
            </div>
          </.form>
        </div>

        <div class="text-center mt-6 text-sm text-zinc-500">
          <.link
            navigate={~p"/users/log_in"}
            id="cancel-2fa-btn"
            class="font-medium text-zinc-500 hover:text-base-content hover:underline inline-flex items-center gap-1.5"
          >
            <.icon name="hero-arrow-left" class="size-4" /> Annuler et revenir à la connexion
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
