defmodule QuizirWeb.UserRegistrationLiveTest do
  use QuizirWeb.ConnCase

  import Quizir.AccountsFixtures

  describe "Registration page" do
    test "renders registration page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/register")

      assert has_element?(view, "#registration_form")
      assert has_element?(view, "#user_username")
      assert has_element?(view, "#user_password")
      assert has_element?(view, "#user_email")
      assert has_element?(view, "#register-submit-btn")
    end

    test "redirects if already logged in", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/quizzes"}}} = live(conn, ~p"/users/register")
    end

    test "creates account and logs the user in", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/register")

      username = unique_username()
      password = valid_password()

      form =
        form(view, "#registration_form",
          user: %{"username" => username, "password" => password, "email" => ""}
        )

      render_submit(form)
      conn = follow_trigger_action(form, conn)

      assert redirected_to(conn) =~ ~p"/quizzes"

      # User is logged in
      conn = get(conn, ~p"/quizzes")
      assert conn.assigns.current_user != nil
      assert conn.assigns.current_user.username == username
    end

    test "renders validation errors on invalid input", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/register")

      result =
        view
        |> form("#registration_form", user: %{"username" => "ab", "password" => "123"})
        |> render_change()

      assert result =~ "should be at least 3 character(s)"
      assert result =~ "should be at least 6 character(s)"
    end
  end
end
