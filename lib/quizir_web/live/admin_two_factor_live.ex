defmodule QuizirWeb.AdminTwoFactorLive do
  use QuizirWeb, :live_view

  alias Quizir.Accounts

  @impl true
  def mount(_params, session, socket) do
    user_id = session["admin_totp_auth_user_id"]
    user = user_id && Accounts.get_user(user_id)

    if user && user.admin && user.totp_enabled do
      form = to_form(%{"code" => ""}, as: "totp")

      {:ok,
       socket
       |> assign(:page_title, "Administration - Vérification 2FA")
       |> assign(:username, user.username)
       |> assign(:form, form), temporary_assigns: [form: form]}
    else
      {:ok, redirect(socket, to: ~p"/admin/log_in")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} is_admin={true}>
      <div class="max-w-md mx-auto py-12">
        <div class="flex flex-col items-center text-center mb-8">
          <div class="flex items-center justify-center p-3.5 rounded-2xl bg-error/10 text-error ring-1 ring-error/20 mb-3 shadow-inner">
            <.icon name="hero-shield-check" class="size-9" />
          </div>
          <div class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-error/10 text-error mb-2 border border-error/20">
            <.icon name="hero-lock-closed" class="size-3.5" /> Zone sécurisée
          </div>
          <h1 class="text-3xl font-black tracking-tight">Vérification 2FA Admin</h1>
          <p class="text-sm text-zinc-500 mt-2">
            Entrez le code à 6 chiffres pour valider la session administrateur de <span class="font-bold text-base-content">{@username}</span>.
          </p>
        </div>

        <div class="p-8 rounded-3xl bg-base-100 border border-base-300 shadow-xl relative overflow-hidden">
          <div class="absolute top-0 inset-x-0 h-1 bg-gradient-to-r from-error via-purple-600 to-primary">
          </div>

          <.form
            for={@form}
            id="admin_two_factor_form"
            action={~p"/admin/two_factor"}
            phx-update="ignore"
            class="space-y-5"
          >
            <.input
              field={@form[:code]}
              type="text"
              label="Code d'authentification"
              id="admin_totp_code"
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
                id="admin-totp-submit-btn"
                variant="primary"
                class="btn btn-primary btn-lg w-full font-bold shadow-md shadow-primary/20 gap-2"
              >
                <.icon name="hero-check" class="size-5" /> Valider l'accès
              </.button>
            </div>
          </.form>
        </div>

        <div class="text-center mt-6 text-sm text-zinc-500">
          <.link
            navigate={~p"/admin/log_in"}
            id="cancel-admin-2fa-btn"
            class="font-medium text-zinc-500 hover:text-base-content hover:underline inline-flex items-center gap-1.5"
          >
            <.icon name="hero-arrow-left" class="size-4" /> Annuler et revenir
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
