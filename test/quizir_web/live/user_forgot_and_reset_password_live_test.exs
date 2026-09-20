defmodule QuizirWeb.UserForgotAndResetPasswordLiveTest do
  use QuizirWeb.ConnCase

  import Quizir.AccountsFixtures
  alias Quizir.Accounts

  describe "Forgot password page" do
    test "renders forgot password form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/reset_password")

      assert has_element?(view, "#forgot_password_form")
      assert has_element?(view, "#reset_identifier")
      assert has_element?(view, "#forgot-password-submit-btn")
    end

    test "submits forgot password and displays confirmation", %{conn: conn} do
      user = user_fixture()
      {:ok, view, _html} = live(conn, ~p"/users/reset_password")

      html =
        view
        |> form("#forgot_password_form", user: %{"identifier" => user.email})
        |> render_submit()

      assert html =~ "Vérifiez votre boîte de réception"
      assert has_element?(view, "#reset-instructions-sent")
    end
  end

  describe "Reset password page" do
    test "renders reset password form with valid token and resets password", %{conn: conn} do
      user = user_fixture()
      {token, user_token} = Quizir.Accounts.UserToken.build_email_token(user, "reset_password")
      Quizir.Repo.insert!(user_token)

      {:ok, view, _html} = live(conn, ~p"/users/reset_password/#{token}")

      assert has_element?(view, "#reset_password_form")
      assert has_element?(view, "#new_user_password")

      new_password = "brandnewpassword123"

      {:ok, _login_view, html} =
        view
        |> form("#reset_password_form", user: %{"password" => new_password})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log_in")

      assert html =~ "Votre mot de passe a été modifié avec succès."

      # Can login with new password
      assert {:ok, _} = Accounts.get_user_by_username_and_password(user.username, new_password)
    end

    test "redirects with error if token is invalid", %{conn: conn} do
      {:ok, _login_view, html} =
        live(conn, ~p"/users/reset_password/invalid-token")
        |> follow_redirect(conn, ~p"/users/log_in")

      assert html =~ "Le lien de réinitialisation est invalide ou a expiré."
    end
  end
end
