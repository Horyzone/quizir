defmodule QuizirWeb.UserSettingsLiveTest do
  use QuizirWeb.ConnCase

  import Quizir.AccountsFixtures
  alias Quizir.Accounts
  alias Quizir.Accounts.User

  describe "User settings page access" do
    test "redirects unauthenticated user to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log_in"}}} = live(conn, ~p"/users/settings")
    end

    test "renders settings page for authenticated user", %{conn: conn} do
      user = user_fixture(%{username: "testuser", email: "testuser@example.com"})
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/users/settings")

      assert has_element?(view, "#user-display-username", "testuser")
      assert has_element?(view, "#email_form")
      assert has_element?(view, "#password_form")
      assert has_element?(view, "#user_email")
      assert has_element?(view, "#current_password")
      assert has_element?(view, "#user_password")
      assert has_element?(view, "#user_password_confirmation")
      assert has_element?(view, "#save-email-btn")
      assert has_element?(view, "#save-password-btn")
    end
  end

  describe "Update email" do
    setup %{conn: conn} do
      user = user_fixture(%{email: "original@example.com"})
      %{conn: log_in_user(conn, user), user: user}
    end

    test "updates user email with valid email address", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/users/settings")

      new_email = "updated_email@example.com"

      form =
        form(view, "#email_form", %{
          "user" => %{"email" => new_email}
        })

      render_submit(form)

      assert has_element?(
               view,
               "[role=alert]",
               "Votre adresse email a été mise à jour avec succès."
             )

      updated_user = Accounts.get_user!(user.id)
      assert updated_user.email == new_email
    end

    test "allows clearing email", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/users/settings")

      form =
        form(view, "#email_form", %{
          "user" => %{"email" => ""}
        })

      render_submit(form)

      assert has_element?(
               view,
               "[role=alert]",
               "Votre adresse email a été supprimée."
             )

      updated_user = Accounts.get_user!(user.id)
      assert updated_user.email == nil
    end

    test "renders validation error on invalid email", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/settings")

      result =
        view
        |> form("#email_form", %{"user" => %{"email" => "invalid-format"}})
        |> render_change()

      assert result =~ "doit être une adresse email valide"
    end
  end

  describe "Update password" do
    setup %{conn: conn} do
      password = valid_password()
      user = user_fixture(%{password: password})
      %{conn: log_in_user(conn, user), user: user, password: password}
    end

    test "updates password with correct current password", %{
      conn: conn,
      user: user,
      password: current_password
    } do
      {:ok, view, _html} = live(conn, ~p"/users/settings")

      new_password = "new_secret_password_123"

      form =
        form(view, "#password_form", %{
          "user" => %{
            "current_password" => current_password,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)

      assert has_element?(
               view,
               "[role=alert]",
               "Votre mot de passe a été modifié avec succès."
             )

      updated_user = Accounts.get_user!(user.id)
      assert User.valid_password?(updated_user, new_password)
      refute User.valid_password?(updated_user, current_password)
    end

    test "renders error when current password is wrong", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/settings")

      new_password = "new_secret_password_123"

      form =
        form(view, "#password_form", %{
          "user" => %{
            "current_password" => "wrong_current_password",
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      result = render_submit(form)
      assert result =~ "est incorrect"
    end

    test "renders error when password confirmation does not match", %{
      conn: conn,
      password: current_password
    } do
      {:ok, view, _html} = live(conn, ~p"/users/settings")

      result =
        view
        |> form("#password_form", %{
          "user" => %{
            "current_password" => current_password,
            "password" => "secret123",
            "password_confirmation" => "mismatching_secret"
          }
        })
        |> render_change()

      assert result =~ "ne correspond pas au mot de passe"
    end
  end
end
