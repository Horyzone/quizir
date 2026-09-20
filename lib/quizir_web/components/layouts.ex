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

  attr :container_class, :string,
    default: "mx-auto max-w-4xl space-y-4",
    doc: "the class for the inner main container"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="navbar px-4 sm:px-6 lg:px-8 border-b border-base-200 bg-base-100/80 backdrop-blur sticky top-0 z-40">
      <div class="flex-1">
        <.link navigate={~p"/"} class="flex w-fit items-center gap-2">
          <img src={~p"/images/logo.svg"} width="32" height="32" alt="Quizir" class="rounded-lg" />
          <span class="text-xl font-black tracking-tight text-primary">Quizir</span>
        </.link>
      </div>
      <div class="flex-none">
        <ul class="flex px-1 space-x-2 sm:space-x-3 items-center">
          <li>
            <.link navigate={~p"/quizzes"} class="btn btn-ghost btn-sm font-medium">
              Quiz
            </.link>
          </li>
          <li>
            <.link navigate={~p"/join"} class="btn btn-primary btn-sm font-bold gap-1 shadow-sm">
              <.icon name="hero-play" class="size-4" /> Rejoindre
            </.link>
          </li>

          <%= if @current_scope && @current_scope.user do %>
            <li class="dropdown dropdown-end">
              <div
                tabindex="0"
                role="button"
                id="user-menu-btn"
                class="btn btn-ghost btn-sm gap-1 font-semibold"
              >
                <.icon name="hero-user-circle" class="size-4 text-primary" />
                <span class="max-w-[100px] truncate">{@current_scope.user.username}</span>
                <.icon name="hero-chevron-down" class="size-3 text-zinc-400" />
              </div>
              <ul
                tabindex="0"
                class="dropdown-content menu p-2 shadow-lg bg-base-100 rounded-2xl w-48 border border-base-200 mt-2 z-50"
              >
                <li class="menu-title px-4 py-1 text-xs text-zinc-400 font-bold">
                  Connecté en tant que
                  <span class="text-base-content block font-semibold truncate">{@current_scope.user.username}</span>
                </li>
                <li>
                  <.link navigate={~p"/quizzes/new"} class="text-xs font-semibold">
                    <.icon name="hero-plus-circle" class="size-4 text-primary" /> Créer un quiz
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
            </li>
          <% else %>
            <li>
              <.link
                id="nav-login-btn"
                navigate={~p"/users/log_in"}
                class="btn btn-ghost btn-sm font-medium"
              >
                Connexion
              </.link>
            </li>
            <li>
              <.link
                id="nav-register-btn"
                navigate={~p"/users/register"}
                class="btn btn-outline btn-sm font-medium hidden sm:inline-flex"
              >
                S'inscrire
              </.link>
            </li>
          <% end %>

          <li>
            <.theme_toggle />
          </li>
        </ul>
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
