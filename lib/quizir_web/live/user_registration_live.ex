defmodule QuizirWeb.UserRegistrationLive do
  use QuizirWeb, :live_view

  alias Quizir.Accounts
  alias Quizir.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})
    first_user? = not Accounts.any_users?()

    socket =
      socket
      |> assign(trigger_submit: false)
      |> assign_form(changeset)
      |> assign(:first_user?, first_user?)
      |> assign(
        :page_title,
        if(first_user?, do: "Configuration initiale - Premier compte", else: "Inscription")
      )

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    registration_result =
      if socket.assigns.first_user? do
        Accounts.register_initial_admin(user_params)
      else
        Accounts.register_user(user_params)
      end

    case registration_result do
      {:ok, user} ->
        changeset = Accounts.change_user_registration(user)

        {:noreply,
         socket
         |> assign(trigger_submit: true)
         |> assign_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}

      {:error, :initial_admin_already_exists} ->
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
        <div class="flex flex-col items-center text-center mb-8">
          <%= if @first_user? do %>
            <div
              id="initial-setup-icon"
              class="flex items-center justify-center p-3.5 rounded-2xl bg-warning/15 text-warning ring-1 ring-warning/30 mb-3 shadow-inner"
            >
              <.icon name="hero-shield-check" class="size-8" />
            </div>
            <div id="initial-setup-badge" class="flex justify-center mb-2">
              <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-warning/15 text-warning border border-warning/30">
                <.icon name="hero-sparkles" class="size-3.5" /> Configuration initiale
              </span>
            </div>
            <h1 id="registration-title" class="text-3xl font-black tracking-tight">
              Premier compte Quizir
            </h1>
            <p class="text-sm text-zinc-500 mt-2">
              Aucun compte utilisateur n'existe encore. Ce premier compte sera automatiquement doté des <strong class="text-base-content font-bold">droits administrateur</strong>.
            </p>
          <% else %>
            <div class="inline-flex p-3 rounded-2xl bg-primary/10 text-primary mb-3">
              <.icon name="hero-user-plus" class="size-8" />
            </div>
            <h1 id="registration-title" class="text-3xl font-extrabold tracking-tight">
              Créer un compte
            </h1>
            <p class="text-sm text-zinc-500 mt-2">
              Rejoignez Quizir pour créer et gérer vos propres quiz !
            </p>
          <% end %>
        </div>

        <div class="p-8 rounded-3xl bg-base-100 border border-base-300 shadow-xl">
          <%= if @first_user? do %>
            <div
              id="initial-admin-notice"
              class="alert alert-warning text-xs font-semibold py-2.5 px-3.5 mb-4 flex items-center gap-2 border border-warning/30"
            >
              <.icon name="hero-key" class="size-4 shrink-0" />
              <span>Privilèges administrateur complets accordés à ce compte.</span>
            </div>
          <% end %>

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
              placeholder="ex: admin ou quizmaster42"
              required
            />

            <.input
              field={@form[:email]}
              type="email"
              label="Adresse email (optionnel)"
              id="user_email"
              placeholder="ex: admin@exemple.fr"
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
                phx-disable-with={
                  if @first_user?,
                    do: "Configuration du compte admin...",
                    else: "Création du compte..."
                }
                class="btn btn-primary btn-lg w-full font-bold shadow-md shadow-primary/20"
              >
                <%= if @first_user? do %>
                  <.icon name="hero-shield-check" class="size-5 mr-1" />
                  Créer le compte administrateur
                <% else %>
                  S'inscrire <.icon name="hero-arrow-right" class="size-5 ml-1" />
                <% end %>
              </.button>
            </div>
          </.form>
        </div>

        <%= if not @first_user? do %>
          <div class="text-center mt-6 text-sm text-zinc-500">
            Vous avez déjà un compte ?
            <.link navigate={~p"/users/log_in"} class="font-bold text-primary hover:underline ml-1">
              Se connecter
            </.link>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
