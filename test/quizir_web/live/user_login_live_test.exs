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
  end
end
