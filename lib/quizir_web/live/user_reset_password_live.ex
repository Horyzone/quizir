defmodule QuizirWeb.UserResetPasswordLive do
  use QuizirWeb, :live_view

  alias Quizir.Accounts

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    if user = Accounts.get_user_by_reset_password_token(token) do
      form = to_form(Accounts.change_user_password(user), as: "user")

      {:ok,
       socket
       |> assign(
         token: token,
         user: user,
         form: form,
         page_title: "Réinitialiser le mot de passe"
       )}
    else
      {:ok,
       socket
       |> put_flash(:error, "Le lien de réinitialisation est invalide ou a expiré.")
       |> push_navigate(to: ~p"/users/log_in")}
    end
  end

  @impl true
  def handle_event("reset_password", %{"user" => user_params}, socket) do
    case Accounts.reset_user_password(socket.assigns.user, user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Votre mot de passe a été modifié avec succès. Vous pouvez maintenant vous connecter."
         )
         |> push_navigate(to: ~p"/users/log_in")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: "user"))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-md mx-auto py-8">
        <div class="text-center mb-8">
          <div class="inline-flex p-3 rounded-2xl bg-primary/10 text-primary mb-3">
            <.icon name="hero-lock-closed" class="size-8" />
          </div>
          <h1 class="text-3xl font-extrabold tracking-tight">Nouveau mot de passe</h1>
          <p class="text-sm text-zinc-500 mt-2">
            Choisissez un nouveau mot de passe pour votre compte <strong>{@user.username}</strong>.
          </p>
        </div>

        <div class="p-8 rounded-3xl bg-base-100 border border-base-300 shadow-xl">
          <.form
            for={@form}
            id="reset_password_form"
            phx-submit="reset_password"
            class="space-y-4"
          >
            <.input
              field={@form[:password]}
              type="password"
              label="Nouveau mot de passe"
              id="new_user_password"
              placeholder="Minimum 6 caractères"
              required
            />

            <div class="pt-2">
              <.button
                id="reset-password-btn"
                variant="primary"
                phx-disable-with="Enregistrement..."
                class="btn btn-primary btn-lg w-full font-bold shadow-md shadow-primary/20"
              >
                Changer le mot de passe <.icon name="hero-check" class="size-5 ml-1" />
              </.button>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
