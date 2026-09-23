defmodule QuizirWeb.AdminAuth do
  @moduledoc """
  Authentication plugs and LiveView lifecycle hooks for the Admin portal.
  Maintains an isolated session distinct from regular player sessions.
  """
  use QuizirWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Quizir.Accounts

  @doc """
  Logs the admin user in.
  Stores :admin_user_token in the session without touching :user_token.
  """
  def log_in_admin_user(conn, user) do
    token = Accounts.generate_admin_session_token(user)
    admin_return_to = get_session(conn, :admin_return_to)
    user_token = get_session(conn, :user_token) || Accounts.generate_user_session_token(user)

    conn
    |> configure_session(renew: true)
    |> delete_session(:admin_return_to)
    |> put_session(:admin_user_token, token)
    |> put_session(:admin_live_socket_id, "admin_sessions:#{Base.url_encode64(token)}")
    |> put_session(:user_token, user_token)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(user_token)}")
    |> redirect(to: admin_return_to || ~p"/admin")
  end

  @doc """
  Logs the admin user out.
  Removes :admin_user_token from the session without touching :user_token.
  """
  def log_out_admin_user(conn) do
    admin_token = get_session(conn, :admin_user_token)
    admin_token && Accounts.delete_admin_session_token(admin_token)

    if admin_live_socket_id = get_session(conn, :admin_live_socket_id) do
      QuizirWeb.Endpoint.broadcast(admin_live_socket_id, "disconnect", %{})
    end

    conn
    |> configure_session(renew: true)
    |> delete_session(:admin_user_token)
    |> delete_session(:admin_live_socket_id)
    |> delete_session(:admin_return_to)
    |> redirect(to: ~p"/admin/log_in")
  end

  @doc """
  Authenticates the admin user by looking into the session.
  Assigns :current_admin_user in conn.
  """
  def fetch_current_admin_user(conn, _opts) do
    token = get_session(conn, :admin_user_token)
    admin_user = token && Accounts.get_user_by_admin_session_token(token)

    assign(conn, :current_admin_user, admin_user)
  end

  @doc """
  Plug for routes that require an authenticated admin.
  """
  def require_authenticated_admin(conn, _opts) do
    if QuizirWeb.UserAuth.initial_setup_required?() do
      conn
      |> redirect(to: ~p"/users/register")
      |> halt()
    else
      if conn.assigns[:current_admin_user] do
        conn
      else
        conn
        |> put_flash(
          :error,
          "Vous devez être connecté en tant qu'administrateur pour accéder à cette page."
        )
        |> maybe_store_admin_return_to()
        |> redirect(to: ~p"/admin/log_in")
        |> halt()
      end
    end
  end

  @doc """
  Plug for routes that require the admin to NOT be logged in (e.g. /admin/log_in).
  """
  def redirect_if_admin_is_authenticated(conn, _opts) do
    if conn.assigns[:current_admin_user] do
      conn
      |> redirect(to: ~p"/admin")
      |> halt()
    else
      conn
    end
  end

  defp maybe_store_admin_return_to(%{method: "GET"} = conn) do
    put_session(conn, :admin_return_to, current_path(conn))
  end

  defp maybe_store_admin_return_to(conn), do: conn

  ## LiveView Hooks

  def on_mount(:mount_current_admin_user, _params, session, socket) do
    admin_user = get_admin_user_from_session(session)
    player_user = get_player_user_from_session(session)

    {:cont,
     socket
     |> Phoenix.Component.assign_new(:current_admin_user, fn -> admin_user end)
     |> Phoenix.Component.assign_new(:current_user, fn -> player_user end)
     |> Phoenix.Component.assign_new(:current_scope, fn ->
       Quizir.Accounts.Scope.for_user(player_user)
     end)}
  end

  def on_mount(:ensure_authenticated_admin, _params, session, socket) do
    if QuizirWeb.UserAuth.initial_setup_required?() do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/users/register")}
    else
      admin_user = get_admin_user_from_session(session)

      if admin_user do
        player_user = get_player_user_from_session(session)
        QuizirWeb.UserTracker.track_socket(socket, player_user || admin_user)

        {:cont,
         socket
         |> Phoenix.Component.assign_new(:is_admin, fn -> true end)
         |> Phoenix.Component.assign_new(:current_admin_user, fn -> admin_user end)
         |> Phoenix.Component.assign_new(:current_user, fn -> player_user end)
         |> Phoenix.Component.assign_new(:current_scope, fn ->
           Quizir.Accounts.Scope.for_user(player_user)
         end)}
      else
        socket =
          socket
          |> Phoenix.LiveView.put_flash(
            :error,
            "Vous devez être connecté en tant qu'administrateur pour accéder à cette page."
          )
          |> Phoenix.LiveView.redirect(to: ~p"/admin/log_in")

        {:halt, socket}
      end
    end
  end

  def on_mount(:redirect_if_admin_is_authenticated, _params, session, socket) do
    if QuizirWeb.UserAuth.initial_setup_required?() do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/users/register")}
    else
      admin_user = get_admin_user_from_session(session)

      if admin_user do
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/admin")}
      else
        player_user = get_player_user_from_session(session)
        QuizirWeb.UserTracker.track_socket(socket, player_user)

        {:cont,
         socket
         |> Phoenix.Component.assign_new(:is_admin, fn -> true end)
         |> Phoenix.Component.assign_new(:current_admin_user, fn -> nil end)
         |> Phoenix.Component.assign_new(:current_user, fn -> player_user end)
         |> Phoenix.Component.assign_new(:current_scope, fn ->
           Quizir.Accounts.Scope.for_user(player_user)
         end)}
      end
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

  defp get_player_user_from_session(session) do
    case session["user_token"] do
      token when is_binary(token) ->
        Accounts.get_user_by_session_token(token)

      _ ->
        nil
    end
  end
end
