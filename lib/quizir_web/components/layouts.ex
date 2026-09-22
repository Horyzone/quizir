defmodule QuizirWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use QuizirWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  attr :current_admin_user, :map,
    default: nil,
    doc: "the current authenticated admin user"

  attr :is_admin, :boolean,
    default: false,
    doc: "whether to render the admin navbar instead of player navigation"

  attr :container_class, :string,
    default: "mx-auto max-w-4xl space-y-4",
    doc: "the class for the inner main container"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="navbar justify-between px-3 sm:px-6 lg:px-8 border-b border-base-200 bg-base-100/80 backdrop-blur sticky top-0 z-40">
      <div class="flex items-center shrink-0 gap-2">
        <.link navigate={~p"/"} class="flex items-center gap-2 group shrink-0">
          <img
            src={~p"/images/logo.svg"}
            width="32"
            height="32"
            alt="Quizir"
            class="rounded-lg transition-transform group-hover:scale-105 shrink-0"
          />
          <span class="text-xl font-black tracking-tight text-primary select-none shrink-0">Quizir</span>
        </.link>
        <%= if @is_admin do %>
          <span
            id="header-admin-badge"
            class="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-error/10 border border-error/30 text-error text-xs font-bold"
          >
            <.icon name="hero-shield-check" class="size-3.5" />
            <span>Admin</span>
          </span>
        <% else %>
          <%= if @current_admin_user do %>
            <.link
              navigate={~p"/admin"}
              id="header-admin-badge"
              class="hidden sm:inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-error/10 border border-error/30 text-error hover:bg-error/20 text-xs font-bold transition-colors"
              title={"Session admin active (#{@current_admin_user.username})"}
            >
              <.icon name="hero-shield-check" class="size-3.5" />
              <span>Admin</span>
            </.link>
          <% end %>
        <% end %>
      </div>

      <!-- Desktop Navigation (md and above) -->
      <div class="hidden md:flex items-center gap-2 lg:gap-3">
        <%= if @is_admin do %>
          <.link
            navigate={~p"/"}
            id="nav-back-to-site-btn"
            class="btn btn-ghost btn-sm font-medium gap-1.5"
            title="Revenir au site public"
          >
            <.icon name="hero-arrow-top-right-on-square" class="size-4" />
            <span>Voir le site</span>
          </.link>

          <%= if @current_admin_user do %>
            <div class="dropdown dropdown-end">
              <div
                tabindex="0"
                role="button"
                id="admin-menu-btn"
                class="btn btn-ghost btn-sm gap-1.5 font-semibold text-error"
              >
                <.icon name="hero-shield-check" class="size-4 text-error" />
                <span class="max-w-[140px] truncate">{@current_admin_user.username}</span>
                <.icon name="hero-chevron-down" class="size-3 text-zinc-400" />
              </div>
              <ul
                tabindex="0"
                class="dropdown-content menu p-2 shadow-lg bg-base-100 rounded-2xl w-52 border border-base-200 mt-2 z-50"
              >
                <li class="menu-title px-4 py-1 text-xs text-zinc-400 font-bold">
                  Administrateur
                  <span class="text-base-content block font-semibold truncate">{@current_admin_user.username}</span>
                </li>
                <li>
                  <.link navigate={~p"/admin"} class="text-xs font-semibold">
                    <.icon name="hero-squares-2x2" class="size-4 text-error" /> Tableau de bord
                  </.link>
                </li>
                <div class="divider my-1"></div>
                <li>
                  <.link
                    id="nav-admin-logout-btn"
                    href={~p"/admin/log_out"}
                    method="delete"
                    class="text-xs text-error font-semibold"
                  >
                    <.icon name="hero-arrow-right-on-rectangle" class="size-4" /> Déconnexion Admin
                  </.link>
                </li>
              </ul>
            </div>
          <% end %>

          <.theme_toggle />
        <% else %>
          <.link navigate={~p"/quizzes"} class="btn btn-ghost btn-sm font-medium">
            Explorer
          </.link>
          <.link
            navigate={~p"/games"}
            id="nav-live-games-btn"
            class="btn btn-ghost btn-sm font-medium gap-1.5"
          >
            <span class="size-2 rounded-full bg-emerald-500 animate-pulse"></span> Parties
          </.link>
          <%= if @current_scope && @current_scope.user do %>
            <.link navigate={~p"/my-quizzes"} class="btn btn-ghost btn-sm font-medium">
              Mes quiz
            </.link>
          <% end %>
          <.link navigate={~p"/join"} class="btn btn-primary btn-sm font-bold gap-1 shadow-sm">
            <.icon name="hero-play" class="size-4" /> Rejoindre
          </.link>

          <%= if @current_admin_user do %>
            <.link
              navigate={~p"/admin"}
              id="nav-admin-btn"
              class="btn btn-error btn-outline btn-sm font-bold gap-1 shadow-xs"
            >
              <.icon name="hero-shield-check" class="size-4" /> Admin
            </.link>
          <% end %>

          <%= if @current_scope && @current_scope.user do %>
            <div class="dropdown dropdown-end">
              <div
                tabindex="0"
                role="button"
                id="user-menu-btn"
                class="btn btn-ghost btn-sm gap-1.5 font-semibold"
              >
                <.icon name="hero-user-circle" class="size-4 text-primary" />
                <span class="max-w-[120px] truncate">{@current_scope.user.username}</span>
                <.icon name="hero-chevron-down" class="size-3 text-zinc-400" />
              </div>
              <ul
                tabindex="0"
                class="dropdown-content menu p-2 shadow-lg bg-base-100 rounded-2xl w-52 border border-base-200 mt-2 z-50"
              >
                <li class="menu-title px-4 py-1 text-xs text-zinc-400 font-bold">
                  Connecté en tant que
                  <span class="text-base-content block font-semibold truncate">{@current_scope.user.username}</span>
                </li>
                <%= if @current_scope.user.admin do %>
                  <li>
                    <.link
                      navigate={~p"/admin"}
                      id="nav-admin-portal-link"
                      class="text-xs font-bold text-error"
                    >
                      <.icon name="hero-shield-check" class="size-4 text-error" /> Administration
                    </.link>
                  </li>
                  <div class="divider my-1"></div>
                <% end %>
                <li>
                  <.link
                    navigate={~p"/my-quizzes"}
                    id="nav-my-quizzes-btn"
                    class="text-xs font-semibold"
                  >
                    <.icon name="hero-rectangle-stack" class="size-4 text-primary" /> Mes quiz
                  </.link>
                </li>
                <li>
                  <.link navigate={~p"/quizzes/new"} class="text-xs font-semibold">
                    <.icon name="hero-plus-circle" class="size-4 text-primary" /> Créer un quiz
                  </.link>
                </li>
                <li>
                  <.link
                    navigate={~p"/users/settings"}
                    id="nav-settings-btn"
                    class="text-xs font-semibold"
                  >
                    <.icon name="hero-cog-6-tooth" class="size-4 text-base-content/70" /> Mon compte
                  </.link>
                </li>
                <div class="divider my-1"></div>
                <li>
                  <.link
                    id="logout-btn"
                    href={~p"/users/log_out"}
                    method="delete"
                    class="text-xs text-error font-semibold"
                  >
                    <.icon name="hero-arrow-right-on-rectangle" class="size-4" /> Déconnexion
                  </.link>
                </li>
              </ul>
            </div>
          <% else %>
            <.link
              id="nav-login-btn"
              navigate={~p"/users/log_in"}
              class="btn btn-ghost btn-sm font-medium"
            >
              Connexion
            </.link>
            <.link
              id="nav-register-btn"
              navigate={~p"/users/register"}
              class="btn btn-outline btn-sm font-medium"
            >
              S'inscrire
            </.link>
          <% end %>

          <.theme_toggle />
        <% end %>
      </div>

      <!-- Mobile Navigation (< md) -->
      <div class="flex md:hidden items-center gap-1.5 sm:gap-2">
        <%= if @is_admin do %>
          <.link
            navigate={~p"/"}
            id="mobile-nav-back-to-site-btn"
            class="btn btn-ghost btn-xs sm:btn-sm font-semibold gap-1"
            title="Revenir au site public"
          >
            <.icon name="hero-arrow-top-right-on-square" class="size-3.5" />
            <span class="hidden xs:inline">Site</span>
          </.link>

          <%= if @current_admin_user do %>
            <.link
              href={~p"/admin/log_out"}
              method="delete"
              id="mobile-nav-admin-logout-btn"
              class="btn btn-ghost btn-error btn-xs sm:btn-sm font-bold gap-1 px-2"
              title="Déconnexion Admin"
            >
              <.icon name="hero-arrow-right-on-rectangle" class="size-3.5" />
              <span class="hidden xs:inline">Quitter</span>
            </.link>
          <% end %>

          <.theme_toggle />
        <% else %>
          <%= if @current_admin_user do %>
            <.link
              navigate={~p"/admin"}
              class="btn btn-error btn-outline btn-xs font-bold gap-1 px-2"
              title="Administration"
            >
              <.icon name="hero-shield-check" class="size-3.5" />
              <span>Admin</span>
            </.link>
          <% end %>

          <.link
            navigate={~p"/join"}
            class="btn btn-primary btn-sm font-bold gap-1 px-2.5 shadow-xs"
            title="Rejoindre avec un PIN"
          >
            <.icon name="hero-play" class="size-4 shrink-0" />
            <span>Rejoindre</span>
          </.link>

          <.theme_toggle />

          <%= if @current_scope && @current_scope.user do %>
            <div class="dropdown dropdown-end">
              <div
                tabindex="0"
                role="button"
                id="mobile-user-menu-btn"
                class="btn btn-ghost btn-sm btn-circle"
                aria-label="Menu utilisateur"
              >
                <.icon name="hero-user-circle" class="size-6 text-primary" />
              </div>
              <ul
                tabindex="0"
                class="dropdown-content menu p-2 shadow-xl bg-base-100 rounded-2xl w-56 border border-base-200 mt-2 z-50"
              >
                <li class="menu-title px-4 py-1 text-xs text-zinc-400 font-bold">
                  Connecté en tant que
                  <span class="text-base-content block font-semibold truncate">{@current_scope.user.username}</span>
                </li>
                <%= if @current_scope.user.admin do %>
                  <li>
                    <.link navigate={~p"/admin"} class="text-xs font-bold text-error py-2">
                      <.icon name="hero-shield-check" class="size-4 text-error" /> Administration
                    </.link>
                  </li>
                  <div class="divider my-1"></div>
                <% end %>
                <li>
                  <.link navigate={~p"/quizzes"} class="text-xs font-semibold py-2">
                    <.icon name="hero-sparkles" class="size-4 text-primary" /> Explorer les quiz
                  </.link>
                </li>
                <li>
                  <.link navigate={~p"/games"} class="text-xs font-semibold py-2">
                    <.icon name="hero-globe-alt" class="size-4 text-emerald-500" /> Parties en cours
                  </.link>
                </li>
                <div class="divider my-1"></div>
                <li>
                  <.link navigate={~p"/my-quizzes"} class="text-xs font-semibold py-2">
                    <.icon name="hero-rectangle-stack" class="size-4 text-primary" /> Mes quiz
                  </.link>
                </li>
                <li>
                  <.link navigate={~p"/quizzes/new"} class="text-xs font-semibold py-2">
                    <.icon name="hero-plus-circle" class="size-4 text-primary" /> Créer un quiz
                  </.link>
                </li>
                <li>
                  <.link navigate={~p"/users/settings"} class="text-xs font-semibold py-2">
                    <.icon name="hero-cog-6-tooth" class="size-4 text-base-content/70" /> Mon compte
                  </.link>
                </li>
                <div class="divider my-1"></div>
                <li>
                  <.link
                    href={~p"/users/log_out"}
                    method="delete"
                    class="text-xs text-error font-semibold py-2"
                  >
                    <.icon name="hero-arrow-right-on-rectangle" class="size-4" /> Déconnexion
                  </.link>
                </li>
              </ul>
            </div>
          <% else %>
            <div class="dropdown dropdown-end">
              <div
                tabindex="0"
                role="button"
                id="mobile-guest-menu-btn"
                class="btn btn-ghost btn-sm btn-circle"
                aria-label="Menu de navigation"
              >
                <.icon name="hero-bars-3" class="size-5" />
              </div>
              <ul
                tabindex="0"
                class="dropdown-content menu p-2 shadow-xl bg-base-100 rounded-2xl w-52 border border-base-200 mt-2 z-50"
              >
                <li>
                  <.link navigate={~p"/quizzes"} class="text-xs font-semibold py-2">
                    <.icon name="hero-sparkles" class="size-4 text-primary" /> Explorer les quiz
                  </.link>
                </li>
                <li>
                  <.link navigate={~p"/games"} class="text-xs font-semibold py-2">
                    <.icon name="hero-globe-alt" class="size-4 text-emerald-500" /> Parties en cours
                  </.link>
                </li>
                <div class="divider my-1"></div>
                <li>
                  <.link navigate={~p"/users/log_in"} class="text-xs font-semibold py-2">
                    <.icon name="hero-arrow-left-on-rectangle" class="size-4 text-primary" />
                    Connexion
                  </.link>
                </li>
                <li>
                  <.link navigate={~p"/users/register"} class="text-xs font-semibold py-2">
                    <.icon name="hero-user-plus" class="size-4 text-primary" /> S'inscrire
                  </.link>
                </li>
              </ul>
            </div>
          <% end %>
        <% end %>
      </div>
    </header>

    <main class="px-4 py-8 sm:px-6 lg:px-8">
      <div class={@container_class}>
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        auto_dismiss={false}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        auto_dismiss={false}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 [[data-theme-source=system]_&]:!left-0 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
