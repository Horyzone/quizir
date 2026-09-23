defmodule QuizirWeb.AdminSessionController do
  use QuizirWeb, :controller

  alias Quizir.Accounts
  alias QuizirWeb.AdminAuth

  def create(conn, %{"admin" => admin_params}) do
    username = Map.get(admin_params, "username", "")
    password = Map.get(admin_params, "password", "")

    case Accounts.get_user_by_username_and_password(username, password) do
      {:ok, %{admin: true} = user} ->
        if user.totp_enabled do
          conn
          |> put_session(:admin_totp_auth_user_id, user.id)
          |> redirect(to: ~p"/admin/two_factor")
        else
          conn
          |> put_flash(:info, "Connexion administrateur réussie. Bienvenue #{user.username} !")
          |> AdminAuth.log_in_admin_user(user)
        end

      {:ok, %{admin: false}} ->
        conn
        |> put_flash(
          :error,
          "Accès refusé. Ce compte ne possède pas les privilèges administrateur."
        )
        |> put_flash(:username, String.slice(username, 0, 160))
        |> redirect(to: ~p"/admin/log_in")

      _ ->
        conn
        |> put_flash(:error, "Identifiants administrateur incorrects.")
        |> put_flash(:username, String.slice(username, 0, 160))
        |> redirect(to: ~p"/admin/log_in")
    end
  end

  def create_two_factor(conn, %{"totp" => %{"code" => code}}) do
    user_id = get_session(conn, :admin_totp_auth_user_id)
    user = user_id && Accounts.get_user(user_id)

    if user && user.admin && user.totp_enabled && Accounts.validate_user_totp(user, code) do
      conn
      |> delete_session(:admin_totp_auth_user_id)
      |> put_flash(:info, "Connexion administrateur réussie. Bienvenue #{user.username} !")
      |> AdminAuth.log_in_admin_user(user)
    else
      conn
      |> put_flash(:error, "Code de vérification 2FA administrateur invalide ou expiré.")
      |> redirect(to: ~p"/admin/two_factor")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Session administrateur déconnectée.")
    |> AdminAuth.log_out_admin_user()
  end
end
