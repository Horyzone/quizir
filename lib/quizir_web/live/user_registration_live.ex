defmodule QuizirWeb.UserRegistrationLive do
  use QuizirWeb, :live_view

  alias Quizir.Accounts
  alias Quizir.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})

    socket =
      socket
      |> assign(trigger_submit: false)
      |> assign_form(changeset)
      |> assign(:page_title, "Inscription")

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        changeset = Accounts.change_user_registration(user)

        {:noreply,
         socket
         |> assign(trigger_submit: true)
         |> assign_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-md mx-auto py-8">
        <div class="text-center mb-8">
          <div class="inline-flex p-3 rounded-2xl bg-primary/10 text-primary mb-3">
            <.icon name="hero-user-plus" class="size-8" />
          </div>
          <h1 class="text-3xl font-extrabold tracking-tight">Créer un compte</h1>
          <p class="text-sm text-zinc-500 mt-2">
            Rejoignez Quizir pour créer et gérer vos propres quiz !
          </p>
        </div>

        <div class="p-8 rounded-3xl bg-base-100 border border-base-300 shadow-xl">
          <.form
            for={@form}
            id="registration_form"
            phx-submit="save"
            phx-change="validate"
            phx-trigger-action={@trigger_submit}
            action={~p"/users/log_in"}
            method="post"
            class="space-y-4"
          >
            <.input
              field={@form[:username]}
              type="text"
              label="Nom d'utilisateur"
              id="user_username"
              placeholder="ex: quizmaster42"
              required
            />

            <.input
              field={@form[:email]}
              type="email"
              label="Adresse email (optionnel)"
              id="user_email"
              placeholder="ex: contact@exemple.fr"
            />
            <p class="text-xs text-zinc-400 -mt-2">
              Utile uniquement pour récupérer votre mot de passe en cas d'oubli.
            </p>

            <.input
              field={@form[:password]}
              type="password"
              label="Mot de passe"
              id="user_password"
              placeholder="Minimum 6 caractères"
              required
            />

            <div class="pt-2">
              <.button
                id="register-submit-btn"
                variant="primary"
                phx-disable-with="Création du compte..."
                class="btn btn-primary btn-lg w-full font-bold shadow-md shadow-primary/20"
              >
                S'inscrire <.icon name="hero-arrow-right" class="size-5 ml-1" />
              </.button>
            </div>
          </.form>
        </div>

        <div class="text-center mt-6 text-sm text-zinc-500">
          Vous avez déjà un compte ?
          <.link navigate={~p"/users/log_in"} class="font-bold text-primary hover:underline ml-1">
            Se connecter
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
