defmodule QuizirWeb.AdminLoginLiveTest do
  use QuizirWeb.ConnCase, async: true

  import Quizir.AccountsFixtures

  describe "Admin Login page" do
    test "renders admin login page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/log_in")

      assert has_element?(view, "#admin_login_form")
      assert has_element?(view, "#admin_username")
      assert has_element?(view, "#admin_password")
      assert has_element?(view, "#admin-login-submit-btn")
    end

    test "redirects to /admin if admin is already logged in", %{conn: conn} do
      admin = admin_user_fixture()
      conn = log_in_admin(conn, admin)

      assert {:error, {:redirect, %{to: "/admin"}}} = live(conn, ~p"/admin/log_in")
    end

    test "allows access if only a regular player is logged in", %{conn: conn} do
      player = user_fixture()
      conn = log_in_user(conn, player)

      {:ok, view, _html} = live(conn, ~p"/admin/log_in")
      assert has_element?(view, "#admin_login_form")
    end

    test "logs admin in with valid credentials via form submission and preserves player session",
         %{
           conn: conn
         } do
      admin = admin_user_fixture()
      player = user_fixture()
      conn = log_in_user(conn, player)
      player_token = get_session(conn, :user_token)

      conn =
        post(conn, ~p"/admin/log_in", %{
          "admin" => %{"username" => admin.username, "password" => valid_password()}
        })

      assert redirected_to(conn) == ~p"/admin"
      assert admin_token = get_session(conn, :admin_user_token)
      assert Quizir.Accounts.get_user_by_admin_session_token(admin_token)
      # Independent session: player session is still active
      assert get_session(conn, :user_token) == player_token
    end

    test "rejects non-admin user credentials", %{conn: conn} do
      non_admin = user_fixture()

      conn =
        post(conn, ~p"/admin/log_in", %{
          "admin" => %{"username" => non_admin.username, "password" => valid_password()}
        })

      assert redirected_to(conn) == ~p"/admin/log_in"
      refute get_session(conn, :admin_user_token)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Accès refusé. Ce compte ne possède pas les privilèges administrateur."
    end

    test "emits error on invalid credentials", %{conn: conn} do
      admin = admin_user_fixture()

      conn =
        post(conn, ~p"/admin/log_in", %{
          "admin" => %{"username" => admin.username, "password" => "wrongpass"}
        })

      assert redirected_to(conn) == ~p"/admin/log_in"
      refute get_session(conn, :admin_user_token)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Identifiants administrateur incorrects."
    end

    test "logs admin out without affecting player session", %{conn: conn} do
      admin = admin_user_fixture()
      player = user_fixture()

      conn =
        conn
        |> log_in_user(player)
        |> log_in_admin(admin)

      player_token = get_session(conn, :user_token)
      assert get_session(conn, :admin_user_token)

      conn = delete(conn, ~p"/admin/log_out")
      assert redirected_to(conn) == ~p"/admin/log_in"
      refute get_session(conn, :admin_user_token)
      # Independent session: player session remains untouched
      assert get_session(conn, :user_token) == player_token
    end
  end
end
