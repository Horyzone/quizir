defmodule QuizirWeb.UserSettingsLive do
  use QuizirWeb, :live_view

  alias Quizir.Accounts
  alias Quizir.Quizzes

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    email_changeset = Accounts.change_user_email(user)
    password_changeset = Accounts.change_user_password_update(user)
    quiz_counts = Quizzes.count_user_quizzes_by_visibility(user)

    socket =
      socket
      |> assign(:page_title, "Mon compte")
      |> assign(:quiz_counts, quiz_counts)
      |> assign(:email_form, to_form(email_changeset, as: "user"))
      |> assign(:password_form, to_form(password_changeset, as: "user"))

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", %{"user" => user_params}, socket) do
    email_form =
      socket.assigns.current_user
      |> Accounts.change_user_email(user_params)
      |> Map.put(:action, :validate)
      |> to_form(as: "user")

    {:noreply, assign(socket, email_form: email_form)}
  end

  @impl true
  def handle_event("update_email", %{"user" => user_params}, socket) do
    case Accounts.update_user_email(socket.assigns.current_user, user_params) do
      {:ok, user} ->
        info_msg =
          if user.email && user.email != "" do
            "Votre adresse email a été mise à jour avec succès."
          else
            "Votre adresse email a été supprimée."
          end

        socket =
          socket
          |> put_flash(:info, info_msg)
          |> assign(:current_user, user)
          |> assign(:current_scope, Quizir.Accounts.Scope.for_user(user))
          |> assign(:email_form, to_form(Accounts.change_user_email(user), as: "user"))

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, email_form: to_form(changeset, as: "user"))}
    end
  end

  @impl true
  def handle_event("validate_password", %{"user" => user_params}, socket) do
    password_form =
      socket.assigns.current_user
      |> Accounts.change_user_password_update(user_params)
      |> Map.put(:action, :validate)
      |> to_form(as: "user")

    {:noreply, assign(socket, password_form: password_form)}
  end

  @impl true
  def handle_event("update_password", %{"user" => user_params}, socket) do
    case Accounts.update_user_password(socket.assigns.current_user, user_params) do
      {:ok, user} ->
        socket =
          socket
          |> put_flash(:info, "Votre mot de passe a été modifié avec succès.")
          |> assign(:current_user, user)
          |> assign(
            :password_form,
            to_form(Accounts.change_user_password_update(user), as: "user")
          )

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset, as: "user"))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto py-8 px-4 sm:px-6">
        <!-- 1. En-tête profil utilisateur -->
        <div class="bg-base-100 border border-base-300 rounded-3xl p-6 sm:p-8 shadow-sm mb-8 flex flex-col md:flex-row items-start md:items-center justify-between gap-6">
          <div class="flex items-center gap-4">
            <div class="size-16 rounded-2xl bg-gradient-to-tr from-indigo-600 via-violet-600 to-pink-500 text-white flex items-center justify-center font-black text-2xl shadow-md shrink-0">
              {String.upcase(String.slice(@current_user.username, 0, 1))}
            </div>
            <div>
              <div class="flex items-center gap-2.5 flex-wrap">
                <h1 id="user-display-username" class="text-2xl font-bold text-base-content">
                  {@current_user.username}
                </h1>
                <span class="badge badge-primary badge-sm font-semibold">
                  Compte actif
                </span>
              </div>
              <p class="text-xs text-base-content/60 mt-1 flex items-center gap-1.5">
                <.icon name="hero-calendar" class="size-3.5" />
                Membre depuis {Calendar.strftime(@current_user.inserted_at, "%d/%m/%Y")}
              </p>
            </div>
          </div>

          <div class="flex items-center gap-3 w-full md:w-auto">
            <.link
              navigate={~p"/my-quizzes"}
              id="my-quizzes-shortcut-btn"
              class="btn btn-outline btn-sm font-bold gap-2 flex-1 md:flex-initial"
            >
              <.icon name="hero-rectangle-stack" class="size-4 text-primary" /> Mes quiz
              <span class="badge badge-primary badge-xs">{@quiz_counts.total}</span>
            </.link>
            <.link
              navigate={~p"/quizzes/new"}
              id="new-quiz-shortcut-btn"
              class="btn btn-primary btn-sm font-bold gap-1 flex-1 md:flex-initial"
            >
              <.icon name="hero-plus" class="size-4" /> Nouveau quiz
            </.link>
          </div>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
          <!-- 2. Section Email -->
          <div class="bg-base-100 border border-base-300 rounded-3xl p-6 shadow-sm flex flex-col justify-between">
            <div>
              <div class="flex items-center justify-between gap-2 mb-4">
                <div class="flex items-center gap-2">
                  <div class="p-2 rounded-xl bg-primary/10 text-primary">
                    <.icon name="hero-envelope" class="size-5" />
                  </div>
                  <h2 class="text-lg font-bold text-base-content">Adresse email</h2>
                </div>
                <%= if @current_user.email && @current_user.email != "" do %>
                  <span class="badge badge-success badge-xs gap-1 font-semibold text-white">
                    <.icon name="hero-check" class="size-3" /> Configurée
                  </span>
                <% else %>
                  <span class="badge badge-warning badge-xs gap-1 font-semibold">
                    <.icon name="hero-exclamation-triangle" class="size-3" /> Facultative
                  </span>
                <% end %>
              </div>

              <p class="text-xs text-base-content/70 mb-6 leading-relaxed">
                Votre email est optionnel. Il est uniquement utilisé pour récupérer l'accès à votre compte en cas d'oubli de votre mot de passe.
              </p>

              <.form
                for={@email_form}
                id="email_form"
                phx-change="validate_email"
                phx-submit="update_email"
                class="space-y-4"
              >
                <.input
                  field={@email_form[:email]}
                  type="email"
                  label="Votre adresse email"
                  id="user_email"
                  placeholder="nom@domaine.com"
                />
                <p class="text-xs text-base-content/50 -mt-2">
                  Laissez vide si vous préférez ne pas renseigner d'adresse email.
                </p>

                <div class="pt-2">
                  <.button
                    id="save-email-btn"
                    phx-disable-with="Enregistrement..."
                    class="btn-primary w-full"
                  >
                    <.icon name="hero-check" class="size-4 mr-1" />
                    {if @current_user.email, do: "Mettre à jour l'email", else: "Enregistrer l'email"}
                  </.button>
                </div>
              </.form>
            </div>
          </div>

          <!-- 3. Section Mot de passe -->
          <div class="bg-base-100 border border-base-300 rounded-3xl p-6 shadow-sm flex flex-col justify-between">
            <div>
              <div class="flex items-center gap-2 mb-4">
                <div class="p-2 rounded-xl bg-primary/10 text-primary">
                  <.icon name="hero-lock-closed" class="size-5" />
                </div>
                <h2 class="text-lg font-bold text-base-content">Mot de passe</h2>
              </div>

              <p class="text-xs text-base-content/70 mb-6 leading-relaxed">
                Assurez-vous d'utiliser un mot de passe sécurisé comportant au minimum 6 caractères.
              </p>

              <.form
                for={@password_form}
                id="password_form"
                phx-change="validate_password"
                phx-submit="update_password"
                class="space-y-4"
              >
                <.input
                  field={@password_form[:current_password]}
                  type="password"
                  label="Mot de passe actuel"
                  id="current_password"
                  placeholder="••••••••"
                  required
                />

                <.input
                  field={@password_form[:password]}
                  type="password"
                  label="Nouveau mot de passe"
                  id="user_password"
                  placeholder="••••••••"
                  required
                />

                <.input
                  field={@password_form[:password_confirmation]}
                  type="password"
                  label="Confirmation du mot de passe"
                  id="user_password_confirmation"
                  placeholder="••••••••"
                  required
                />

                <div class="pt-2">
                  <.button
                    id="save-password-btn"
                    phx-disable-with="Modification..."
                    class="btn-primary w-full"
                  >
                    <.icon name="hero-key" class="size-4 mr-1" /> Modifier mon mot de passe
                  </.button>
                </div>
              </.form>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
