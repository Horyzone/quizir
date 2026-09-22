defmodule QuizirWeb.UserAuth do
  @moduledoc """
  Authentication plugs and LiveView lifecycle hooks.
  """
  use QuizirWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Quizir.Accounts
  alias Quizir.Accounts.Scope

  @remember_me_cookie "_quizir_web_user_remember_me"
  @remember_me_options [sign: true, max_age: 60 * 60 * 24 * 60, same_site: "Lax"]

  @doc """
  Logs the user in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.

  It also sets a :live_socket_id key in the session,
  so LiveViews can identify which user is connected.
  """
  def log_in_user(conn, user, params \\ %{}) do
    token = Accounts.generate_user_session_token(user)
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> renew_session()
    |> put_token_in_session(token)
    |> maybe_write_remember_me_cookie(token, params)
    |> redirect(to: user_return_to || ~p"/quizzes")
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params) do
    conn
  end

  # This function renews the session ID and erases the user session
  # while preserving the independent admin session token if present.
  defp renew_session(conn) do
    admin_token = get_session(conn, :admin_user_token)
    delete_csrf_token()

    conn =
      conn
      |> configure_session(renew: true)
      |> clear_session()

    if admin_token do
      put_session(conn, :admin_user_token, admin_token)
    else
      conn
    end
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.delete_user_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      QuizirWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: ~p"/quizzes")
  end

  @doc """
  Authenticates the user by looking into the session
  and remember me token.
  """
  def fetch_current_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)
    user = user_token && Accounts.get_user_by_session_token(user_token)

    conn
    |> assign(:current_user, user)
    |> assign(:current_scope, Scope.for_user(user))
  end

  defp ensure_user_token(conn) do
    if token = get_session(conn, :user_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if token = conn.cookies[@remember_me_cookie] do
        {token, put_token_in_session(conn, token)}
      else
        {nil, conn}
      end
    end
  end

  @doc """
  Used for routes that require the user to not be authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: ~p"/quizzes")
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "Vous devez être connecté pour accéder à cette page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/users/log_in")
      |> halt()
    end
  end

  @doc """
  Plug that enforces redirection to the initial administrator account creation form
  if no user accounts exist in the database.
  """
  def ensure_initial_user_setup(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      if initial_setup_required?() and not setup_path?(conn) do
        conn
        |> put_flash(
          :info,
          "Veuillez créer le premier compte administrateur pour initialiser Quizir."
        )
        |> redirect(to: ~p"/users/register")
        |> halt()
      else
        conn
      end
    end
  end

  @doc """
  Returns true if the application requires initial administrator setup.
  """
  def initial_setup_required? do
    force_initial_setup?() and not Accounts.any_users?()
  end

  defp force_initial_setup? do
    Application.get_env(:quizir, :force_initial_admin_setup, true)
  end

  defp setup_path?(conn) do
    path = conn.request_path
    method = conn.method

    cond do
      path == ~p"/users/register" -> true
      path == ~p"/users/log_in" and method == "POST" -> true
      path in [~p"/mentions-legales", ~p"/cgu", ~p"/rgpd"] -> true
      String.starts_with?(path, "/legal") -> true
      String.starts_with?(path, "/dev") -> true
      true -> false
    end
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  ## LiveView Hooks

  def on_mount(:mount_current_user, _params, session, socket) do
    if initial_setup_required?() and socket.view != QuizirWeb.LegalLive.Show do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/users/register")}
    else
      user = get_user_from_session(session)
      admin_user = get_admin_user_from_session(session)
      QuizirWeb.UserTracker.track_socket(socket, user)

      {:cont,
       socket
       |> Phoenix.Component.assign_new(:current_user, fn -> user end)
       |> Phoenix.Component.assign_new(:current_scope, fn -> Scope.for_user(user) end)
       |> Phoenix.Component.assign_new(:current_admin_user, fn -> admin_user end)}
    end
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    if initial_setup_required?() do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/users/register")}
    else
      user = get_user_from_session(session)
      admin_user = get_admin_user_from_session(session)

      if user do
        QuizirWeb.UserTracker.track_socket(socket, user)

        {:cont,
         socket
         |> Phoenix.Component.assign_new(:current_user, fn -> user end)
         |> Phoenix.Component.assign_new(:current_scope, fn -> Scope.for_user(user) end)
         |> Phoenix.Component.assign_new(:current_admin_user, fn -> admin_user end)}
      else
        socket =
          socket
          |> Phoenix.LiveView.put_flash(
            :error,
            "Vous devez être connecté pour accéder à cette page."
          )
          |> Phoenix.LiveView.redirect(to: ~p"/users/log_in")

        {:halt, socket}
      end
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    user = get_user_from_session(session)
    admin_user = get_admin_user_from_session(session)

    cond do
      user ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/quizzes")}

      initial_setup_required?() and socket.view != QuizirWeb.UserRegistrationLive ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/users/register")}

      true ->
        QuizirWeb.UserTracker.track_socket(socket, nil)

        {:cont,
         socket
         |> Phoenix.Component.assign_new(:current_user, fn -> nil end)
         |> Phoenix.Component.assign_new(:current_scope, fn -> Scope.for_user(nil) end)
         |> Phoenix.Component.assign_new(:current_admin_user, fn -> admin_user end)}
    end
  end

  defp get_user_from_session(session) do
    case session["user_token"] do
      token when is_binary(token) ->
        Accounts.get_user_by_session_token(token)

      _ ->
        nil
    end
  end

  defp get_admin_user_from_session(session) do
    case session["admin_user_token"] do
      token when is_binary(token) ->
        Accounts.get_user_by_admin_session_token(token)

      _ ->
        nil
    end
  end
end
