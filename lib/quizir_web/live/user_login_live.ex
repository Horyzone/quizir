defmodule QuizirWeb.UserLoginLive do
  use QuizirWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    username = Phoenix.Flash.get(socket.assigns.flash, :username)

    form =
      to_form(%{"username" => username, "password" => "", "remember_me" => "false"}, as: "user")

    {:ok, assign(socket, form: form, page_title: "Connexion"), temporary_assigns: [form: form]}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-md mx-auto py-8">
        <div class="text-center mb-8">
          <div class="inline-flex p-3 rounded-2xl bg-primary/10 text-primary mb-3">
            <.icon name="hero-arrow-right-on-rectangle" class="size-8" />
          </div>
          <h1 class="text-3xl font-extrabold tracking-tight">Connexion</h1>
          <p class="text-sm text-zinc-500 mt-2">
            Connectez-vous pour retrouver et gérer vos quiz
          </p>
        </div>

        <div class="p-8 rounded-3xl bg-base-100 border border-base-300 shadow-xl">
          <.form
            for={@form}
            id="login_form"
            action={~p"/users/log_in"}
            phx-update="ignore"
            class="space-y-4"
          >
            <.input
              field={@form[:username]}
              type="text"
              label="Nom d'utilisateur ou email"
              id="user_username"
              placeholder="Votre nom d'utilisateur ou email"
              required
            />

            <.input
              field={@form[:password]}
              type="password"
              label="Mot de passe"
              id="user_password"
              placeholder="Votre mot de passe"
              required
            />

            <div class="flex items-center justify-between text-sm">
              <label class="cursor-pointer flex items-center gap-2">
                <input
                  type="checkbox"
                  name="user[remember_me]"
                  id="user_remember_me"
                  value="true"
                  class="checkbox checkbox-sm checkbox-primary"
                />
                <span class="text-xs text-zinc-600">Se souvenir de moi</span>
              </label>

              <.link
                navigate={~p"/users/reset_password"}
                class="text-xs text-primary hover:underline font-semibold"
              >
                Mot de passe oublié ?
              </.link>
            </div>

            <div class="pt-2">
              <.button
                id="login-submit-btn"
                variant="primary"
                class="btn btn-primary btn-lg w-full font-bold shadow-md shadow-primary/20"
              >
                Se connecter <.icon name="hero-arrow-right" class="size-5 ml-1" />
              </.button>
            </div>
          </.form>
        </div>

        <div class="text-center mt-6 text-sm text-zinc-500">
          Pas encore de compte ?
          <.link navigate={~p"/users/register"} class="font-bold text-primary hover:underline ml-1">
            Créer un compte
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
