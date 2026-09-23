defmodule QuizirWeb.UserLoginLiveTest do
  use QuizirWeb.ConnCase

  import Quizir.AccountsFixtures

  describe "Login page" do
    test "renders login page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/log_in")

      assert has_element?(view, "#login_form")
      assert has_element?(view, "#user_username")
      assert has_element?(view, "#user_password")
      assert has_element?(view, "#login-submit-btn")
    end

    test "redirects if already logged in", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/quizzes"}}} = live(conn, ~p"/users/log_in")
    end

    test "logs user in with valid credentials via form submission", %{conn: conn} do
      user = user_fixture()

      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{"username" => user.username, "password" => valid_password()}
        })

      assert redirected_to(conn) == ~p"/quizzes"

      conn = get(conn, ~p"/quizzes")
      assert conn.assigns.current_user != nil
      assert conn.assigns.current_user.id == user.id
    end

    test "emits error on invalid credentials", %{conn: conn} do
      user = user_fixture()

      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{"username" => user.username, "password" => "wrongpass"}
        })

      assert redirected_to(conn) == ~p"/users/log_in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Nom d'utilisateur ou mot de passe incorrect."
    end

    test "logs the user out", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      conn = delete(conn, ~p"/users/log_out")
      assert redirected_to(conn) == ~p"/quizzes"

      conn = get(conn, ~p"/quizzes")
      assert conn.assigns.current_user == nil
    end

    test "logs user in with email address instead of username", %{conn: conn} do
      user = user_fixture(%{email: "login_email@example.com"})

      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{"username" => user.email, "password" => valid_password()}
        })

      assert redirected_to(conn) == ~p"/quizzes"

      conn = get(conn, ~p"/quizzes")
      assert conn.assigns.current_user != nil
      assert conn.assigns.current_user.id == user.id
    end

    test "redirects to 2FA verification when user has 2FA enabled", %{conn: conn} do
      secret = NimbleTOTP.secret()
      user = user_fixture()

      {:ok, user} =
        Quizir.Repo.update(
          Ecto.Changeset.change(user, %{totp_enabled: true, totp_secret: secret})
        )

      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{"username" => user.username, "password" => valid_password()}
        })

      assert redirected_to(conn) == ~p"/users/two_factor"
      assert get_session(conn, :totp_auth_user_id) == user.id

      # Render 2FA LiveView
      {:ok, view, _html} = live(conn, ~p"/users/two_factor")
      assert has_element?(view, "#two_factor_form")
      assert has_element?(view, "#totp_code")
      assert has_element?(view, "#totp-submit-btn")
    end

    test "completes login when entering valid 2FA code", %{conn: conn} do
      secret = NimbleTOTP.secret()
      user = user_fixture()

      {:ok, user} =
        Quizir.Repo.update(
          Ecto.Changeset.change(user, %{totp_enabled: true, totp_secret: secret})
        )

      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{"username" => user.username, "password" => valid_password()}
        })

      assert redirected_to(conn) == ~p"/users/two_factor"

      valid_code = NimbleTOTP.verification_code(secret)

      conn =
        post(conn, ~p"/users/two_factor", %{
          "totp" => %{"code" => valid_code}
        })

      assert redirected_to(conn) == ~p"/quizzes"
      assert get_session(conn, :totp_auth_user_id) == nil

      conn = get(conn, ~p"/quizzes")
      assert conn.assigns.current_user != nil
      assert conn.assigns.current_user.id == user.id
    end

    test "rejects invalid 2FA code", %{conn: conn} do
      secret = NimbleTOTP.secret()
      user = user_fixture()

      {:ok, user} =
        Quizir.Repo.update(
          Ecto.Changeset.change(user, %{totp_enabled: true, totp_secret: secret})
        )

      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{"username" => user.username, "password" => valid_password()}
        })

      assert redirected_to(conn) == ~p"/users/two_factor"

      conn =
        post(conn, ~p"/users/two_factor", %{
          "totp" => %{"code" => "000000"}
        })

      assert redirected_to(conn) == ~p"/users/two_factor"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Code de vérification 2FA invalide"
    end
  end
end
