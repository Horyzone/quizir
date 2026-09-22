defmodule QuizirWeb.AdminAuthTest do
  use QuizirWeb.ConnCase, async: true

  alias Quizir.Accounts
  alias QuizirWeb.AdminAuth
  import Quizir.AccountsFixtures

  setup %{conn: conn} do
    admin = admin_user_fixture()
    player = user_fixture()
    %{conn: conn, admin: admin, player: player}
  end

  describe "log_in_admin_user/2" do
    test "stores the admin token in session and preserves player token", %{
      conn: conn,
      admin: admin,
      player: player
    } do
      player_token = Accounts.generate_user_session_token(player)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, player_token)
        |> AdminAuth.log_in_admin_user(admin)

      assert redirected_to(conn) == ~p"/admin"
      assert admin_token = get_session(conn, :admin_user_token)
      assert Accounts.get_user_by_admin_session_token(admin_token)
      # Independent session: player token is preserved
      assert get_session(conn, :user_token) == player_token
    end

    test "redirects to admin_return_to when set", %{conn: conn, admin: admin} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{admin_return_to: "/admin?tab=games"})
        |> AdminAuth.log_in_admin_user(admin)

      assert redirected_to(conn) == "/admin?tab=games"
      refute get_session(conn, :admin_return_to)
    end
  end

  describe "log_out_admin_user/1" do
    test "erases the admin token but preserves the player session", %{
      conn: conn,
      admin: admin,
      player: player
    } do
      admin_token = Accounts.generate_admin_session_token(admin)
      player_token = Accounts.generate_user_session_token(player)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:admin_user_token, admin_token)
        |> Plug.Conn.put_session(:user_token, player_token)
        |> AdminAuth.log_out_admin_user()

      assert redirected_to(conn) == ~p"/admin/log_in"
      refute get_session(conn, :admin_user_token)
      refute Accounts.get_user_by_admin_session_token(admin_token)
      # Independent session: player token is still valid and present
      assert get_session(conn, :user_token) == player_token
    end
  end

  describe "fetch_current_admin_user/2" do
    test "authenticates admin from session", %{conn: conn, admin: admin} do
      admin_token = Accounts.generate_admin_session_token(admin)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:admin_user_token, admin_token)
        |> AdminAuth.fetch_current_admin_user([])

      assert conn.assigns.current_admin_user.id == admin.id
    end

    test "does not authenticate if user is demoted", %{conn: conn, admin: admin} do
      admin_token = Accounts.generate_admin_session_token(admin)

      # Demote admin
      {:ok, _} =
        admin
        |> Quizir.Accounts.User.admin_changeset(%{admin: false})
        |> Quizir.Repo.update()

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:admin_user_token, admin_token)
        |> AdminAuth.fetch_current_admin_user([])

      refute conn.assigns.current_admin_user
    end

    test "assigns nil when no admin token is in session", %{conn: conn} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AdminAuth.fetch_current_admin_user([])

      refute conn.assigns.current_admin_user
    end
  end

  describe "require_authenticated_admin/2" do
    test "redirects unauthenticated admin to /admin/log_in and saves return path", %{conn: conn} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Phoenix.Controller.fetch_flash([])
        |> AdminAuth.fetch_current_admin_user([])
        |> Map.put(:request_path, "/admin")
        |> AdminAuth.require_authenticated_admin([])

      assert conn.halted
      assert redirected_to(conn) == ~p"/admin/log_in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "connecté en tant qu'administrateur"
    end

    test "does nothing if admin is already authenticated", %{conn: conn, admin: admin} do
      conn =
        conn
        |> assign(:current_admin_user, admin)
        |> AdminAuth.require_authenticated_admin([])

      refute conn.halted
      refute conn.status
    end
  end

  describe "redirect_if_admin_is_authenticated/2" do
    test "redirects if admin is authenticated", %{conn: conn, admin: admin} do
      conn =
        conn
        |> assign(:current_admin_user, admin)
        |> AdminAuth.redirect_if_admin_is_authenticated([])

      assert conn.halted
      assert redirected_to(conn) == ~p"/admin"
    end

    test "does not redirect if admin is not authenticated", %{conn: conn} do
      conn = AdminAuth.redirect_if_admin_is_authenticated(conn, [])
      refute conn.halted
      refute conn.status
    end
  end
end
