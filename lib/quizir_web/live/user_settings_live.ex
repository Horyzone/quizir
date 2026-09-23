defmodule QuizirWeb.UserSettingsLive do
  use QuizirWeb, :live_view

  on_mount {QuizirWeb.UserAuth, :ensure_authenticated}

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
      |> assign(:totp_setup, nil)
      |> assign(:totp_form, nil)
      |> assign(:disable_totp_form, to_form(%{"current_password" => ""}, as: "disable_totp"))

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
  def handle_event("start_2fa_setup", _params, socket) do
    user = socket.assigns.current_user
    secret = Accounts.generate_totp_secret()
    uri = Accounts.totp_uri(user, secret)
    qr_svg = Accounts.totp_qr_svg(uri)
    formatted_secret = Accounts.totp_formatted_secret(secret)

    totp_setup = %{
      secret: secret,
      uri: uri,
      qr_svg: qr_svg,
      formatted_secret: formatted_secret
    }

    socket =
      socket
      |> assign(:totp_setup, totp_setup)
      |> assign(:totp_form, to_form(%{"code" => ""}, as: "totp"))

    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_2fa_setup", _params, socket) do
    {:noreply, assign(socket, totp_setup: nil, totp_form: nil)}
  end

  @impl true
  def handle_event("confirm_2fa_setup", %{"totp" => %{"code" => code}}, socket) do
    case socket.assigns.totp_setup do
      %{secret: secret} ->
        case Accounts.enable_user_totp(socket.assigns.current_user, secret, code) do
          {:ok, user} ->
            socket =
              socket
              |> put_flash(:info, "Authentification à deux facteurs activée avec succès !")
              |> assign(:current_user, user)
              |> assign(:current_scope, Quizir.Accounts.Scope.for_user(user))
              |> assign(:totp_setup, nil)
              |> assign(:totp_form, nil)
              |> assign(
                :disable_totp_form,
                to_form(%{"current_password" => ""}, as: "disable_totp")
              )

            {:noreply, socket}

          {:error, :invalid_totp_code} ->
            totp_form =
              to_form(%{"code" => code},
                as: "totp",
                errors: [code: {"Code à 6 chiffres incorrect ou expiré.", []}]
              )

            socket =
              socket
              |> put_flash(
                :error,
                "Code 2FA incorrect. Veuillez vérifier le code sur votre application."
              )
              |> assign(:totp_form, totp_form)

            {:noreply, socket}
        end

      nil ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "disable_2fa",
        %{"disable_totp" => %{"current_password" => current_password}},
        socket
      ) do
    case Accounts.disable_user_totp(socket.assigns.current_user, current_password) do
      {:ok, user} ->
        socket =
          socket
          |> put_flash(:info, "L'authentification à deux facteurs a été désactivée.")
          |> assign(:current_user, user)
          |> assign(:current_scope, Quizir.Accounts.Scope.for_user(user))
          |> assign(:totp_setup, nil)
          |> assign(:totp_form, nil)
          |> assign(
            :disable_totp_form,
            to_form(%{"current_password" => ""}, as: "disable_totp")
          )

        {:noreply, socket}

      {:error, :invalid_password} ->
        disable_totp_form =
          to_form(%{"current_password" => ""},
            as: "disable_totp",
            errors: [current_password: {"Mot de passe incorrect.", []}]
          )

        socket =
          socket
          |> put_flash(:error, "Mot de passe incorrect. Impossible de désactiver le 2FA.")
          |> assign(:disable_totp_form, disable_totp_form)

        {:noreply, socket}
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

          <!-- 4. Section 2FA (Authentification à deux facteurs) -->
          <div class="col-span-1 md:col-span-2 bg-base-100 border border-base-300 rounded-3xl p-6 sm:p-8 shadow-sm">
            <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-6 border-b border-base-200">
              <div class="flex items-center gap-3">
                <div class="p-2.5 rounded-2xl bg-primary/10 text-primary shrink-0">
                  <.icon name="hero-shield-check" class="size-6" />
                </div>
                <div>
                  <h2 class="text-xl font-bold text-base-content">
                    Authentification à deux facteurs (2FA)
                  </h2>
                  <p class="text-xs text-base-content/70 mt-0.5">
                    Sécurisez votre compte avec une application d'authentification TOTP (Google Authenticator, Authy, Aegis...)
                  </p>
                </div>
              </div>

              <div>
                <%= if @current_user.totp_enabled do %>
                  <span
                    id="totp-status-badge"
                    class="badge badge-success badge-sm gap-1.5 font-bold text-white py-3 px-3"
                  >
                    <.icon name="hero-check" class="size-3.5" /> Activée
                  </span>
                <% else %>
                  <span
                    id="totp-status-badge"
                    class="badge badge-ghost badge-sm gap-1.5 font-bold text-base-content/60 py-3 px-3"
                  >
                    <.icon name="hero-no-symbol" class="size-3.5" /> Désactivée
                  </span>
                <% end %>
              </div>
            </div>

            <div class="pt-6">
              <%= if @current_user.totp_enabled do %>
                <!-- 2FA is currently active -->
                <div class="space-y-6">
                  <div class="p-4 rounded-2xl bg-success/10 border border-success/20 flex items-start gap-3">
                    <.icon name="hero-check-circle" class="size-5 text-success shrink-0 mt-0.5" />
                    <div>
                      <p class="text-sm font-bold text-success-content">
                        L'authentification à deux facteurs est active sur votre compte
                      </p>
                      <p class="text-xs text-base-content/70 mt-1">
                        Un code de vérification à 6 chiffres vous est demandé à chaque connexion après la saisie de votre mot de passe.
                      </p>
                    </div>
                  </div>

                  <div class="pt-2">
                    <h3 class="text-sm font-bold text-base-content mb-2 flex items-center gap-2">
                      <.icon name="hero-shield-exclamation" class="size-4 text-error" />
                      Désactiver l'authentification à deux facteurs
                    </h3>
                    <p class="text-xs text-base-content/70 mb-4">
                      Pour désactiver le 2FA, veuillez confirmer votre mot de passe actuel.
                    </p>

                    <.form
                      for={@disable_totp_form}
                      id="disable_2fa_form"
                      phx-submit="disable_2fa"
                      class="max-w-lg"
                    >
                      <div class="space-y-1.5">
                        <label
                          for="disable_totp_password"
                          class="text-xs font-bold text-base-content block"
                        >
                          Mot de passe actuel
                        </label>
                        <div class="flex flex-col sm:flex-row items-stretch sm:items-start gap-3">
                          <div class="flex-1 w-full [&_.fieldset]:!p-0 [&_.fieldset]:!mb-0 [&_.fieldset]:!gap-0">
                            <.input
                              field={@disable_totp_form[:current_password]}
                              type="password"
                              id="disable_totp_password"
                              placeholder="••••••••"
                              required
                            />
                          </div>
                          <.button
                            id="disable-2fa-btn"
                            type="submit"
                            class="btn btn-error btn-outline font-bold gap-1.5 shrink-0"
                          >
                            <.icon name="hero-trash" class="size-4" /> Désactiver le 2FA
                          </.button>
                        </div>
                      </div>
                    </.form>
                  </div>
                </div>
              <% else %>
                <%= if @totp_setup do %>
                  <!-- 2FA setup in progress -->
                  <div id="totp-setup-panel" class="space-y-6">
                    <div class="p-4 rounded-2xl bg-primary/10 border border-primary/20 text-sm">
                      <p class="font-bold text-primary flex items-center gap-2">
                        <.icon name="hero-information-circle" class="size-5" />
                        Configuration du 2FA en 2 étapes simples
                      </p>
                      <p class="text-xs text-base-content/70 mt-1">
                        Suivez les instructions ci-dessous puis entrez le premier code généré pour valider l'activation.
                      </p>
                    </div>

                    <div class="grid grid-cols-1 md:grid-cols-2 gap-8 items-start">
                      <!-- Étape 1 : QR Code et Clé secrète -->
                      <div class="space-y-4">
                        <div class="flex items-center gap-2">
                          <span class="size-6 rounded-full bg-primary text-primary-content text-xs font-bold flex items-center justify-center">1</span>
                          <h3 class="text-sm font-bold text-base-content">
                            Scannez le QR Code
                          </h3>
                        </div>

                        <div class="flex flex-col items-center sm:items-start">
                          <div class="p-3 bg-white rounded-2xl shadow-md border border-base-200 inline-block">
                            <div class="size-48 flex items-center justify-center overflow-hidden">
                              {Phoenix.HTML.raw(@totp_setup.qr_svg)}
                            </div>
                          </div>
                        </div>

                        <div class="space-y-1.5">
                          <p class="text-xs text-base-content/60">
                            Impossible de scanner ? Saisissez cette clé dans votre application :
                          </p>
                          <div class="p-2.5 rounded-xl bg-base-200/80 font-mono text-xs font-bold tracking-wider select-all break-all border border-base-300 flex items-center justify-between gap-2">
                            <span id="totp-formatted-key">{@totp_setup.formatted_secret}</span>
                          </div>
                        </div>
                      </div>

                      <!-- Étape 2 : Confirmation du code -->
                      <div class="space-y-4">
                        <div class="flex items-center gap-2">
                          <span class="size-6 rounded-full bg-primary text-primary-content text-xs font-bold flex items-center justify-center">2</span>
                          <h3 class="text-sm font-bold text-base-content">
                            Confirmez avec un code
                          </h3>
                        </div>

                        <p class="text-xs text-base-content/70 leading-relaxed">
                          Saisissez le code à 6 chiffres actuellement affiché dans votre application d'authentification pour confirmer que tout fonctionne.
                        </p>

                        <.form
                          for={@totp_form}
                          id="confirm_2fa_form"
                          phx-submit="confirm_2fa_setup"
                          class="space-y-4 max-w-sm"
                        >
                          <.input
                            field={@totp_form[:code]}
                            type="text"
                            label="Code à 6 chiffres"
                            id="totp_confirm_code"
                            placeholder="000000"
                            maxlength="8"
                            autocomplete="one-time-code"
                            inputmode="numeric"
                            pattern="[0-9]*"
                            class="text-center text-2xl font-mono tracking-widest"
                            required
                            autofocus
                          />

                          <div class="flex items-center gap-3 pt-2">
                            <.button
                              id="confirm-2fa-btn"
                              variant="primary"
                              class="btn btn-primary font-bold flex-1 shadow-md shadow-primary/20 gap-1.5"
                            >
                              <.icon name="hero-check" class="size-4" /> Activer le 2FA
                            </.button>

                            <.button
                              type="button"
                              id="cancel-2fa-setup-btn"
                              phx-click="cancel_2fa_setup"
                              class="btn btn-ghost font-semibold"
                            >
                              Annuler
                            </.button>
                          </div>
                        </.form>
                      </div>
                    </div>
                  </div>
                <% else %>
                  <!-- 2FA inactive, not configuring -->
                  <div class="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 p-5 rounded-2xl bg-base-200/50 border border-base-200">
                    <div class="space-y-1">
                      <p class="text-sm font-bold text-base-content">
                        L'authentification à deux facteurs n'est pas activée
                      </p>
                      <p class="text-xs text-base-content/70">
                        Renforcez la sécurité de votre compte en activant le 2FA dès maintenant.
                      </p>
                    </div>

                    <.button
                      id="start-2fa-setup-btn"
                      type="button"
                      phx-click="start_2fa_setup"
                      class="btn btn-primary font-bold gap-2 shrink-0 shadow-sm"
                    >
                      <.icon name="hero-qr-code" class="size-4" /> Activer le 2FA
                    </.button>
                  </div>
                <% end %>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
