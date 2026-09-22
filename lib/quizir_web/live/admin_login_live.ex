defmodule QuizirWeb.AdminLoginLive do
  use QuizirWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    username = Phoenix.Flash.get(socket.assigns.flash, :username)
    form = to_form(%{"username" => username, "password" => ""}, as: "admin")

    {:ok,
     assign(socket,
       form: form,
       page_title: "Administration - Connexion",
       current_scope: socket.assigns[:current_scope] || %Quizir.Accounts.Scope{user: nil}
     ), temporary_assigns: [form: form]}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-md mx-auto py-12">
        <div class="text-center mb-8">
          <div class="inline-flex p-3.5 rounded-2xl bg-error/10 text-error ring-1 ring-error/20 mb-3 shadow-inner">
            <.icon name="hero-shield-check" class="size-9" />
          </div>
          <div class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-error/10 text-error mb-2 border border-error/20">
            <.icon name="hero-lock-closed" class="size-3.5" /> Zone sécurisée
          </div>
          <h1 class="text-3xl font-black tracking-tight">Portail Administrateur</h1>
          <p class="text-sm text-zinc-500 mt-2">
            Session d'accès distincte réservée aux administrateurs Quizir
          </p>
        </div>

        <div class="p-8 rounded-3xl bg-base-100 border border-base-300 shadow-xl relative overflow-hidden">
          <div class="absolute top-0 inset-x-0 h-1 bg-gradient-to-r from-error via-purple-600 to-primary">
          </div>

          <.form
            for={@form}
            id="admin_login_form"
            action={~p"/admin/log_in"}
            phx-update="ignore"
            class="space-y-4"
          >
            <.input
              field={@form[:username]}
              type="text"
              label="Nom d'utilisateur ou Email"
              id="admin_username"
              placeholder="Pseudo ou adresse email..."
              required
            />

            <.input
              field={@form[:password]}
              type="password"
              label="Mot de passe"
              id="admin_password"
              placeholder="Votre mot de passe..."
              required
            />

            <div class="pt-3">
              <.button
                id="admin-login-submit-btn"
                variant="primary"
                class="btn btn-primary btn-lg w-full font-bold shadow-md shadow-primary/20 gap-2"
              >
                <.icon name="hero-key" class="size-5" /> Accéder au panneau d'administration
              </.button>
            </div>
          </.form>
        </div>

        <div class="text-center mt-6 text-sm text-zinc-500">
          <.link
            navigate={~p"/"}
            class="font-medium text-zinc-500 hover:text-base-content hover:underline inline-flex items-center gap-1"
          >
            <.icon name="hero-arrow-left" class="size-4" /> Retour à la plateforme de jeu
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
