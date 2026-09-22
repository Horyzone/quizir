defmodule QuizirWeb.AdminSessionController do
  use QuizirWeb, :controller

  alias Quizir.Accounts
  alias QuizirWeb.AdminAuth

  def create(conn, %{"admin" => admin_params}) do
    username = Map.get(admin_params, "username", "")
    password = Map.get(admin_params, "password", "")

    case Accounts.get_user_by_username_and_password(username, password) do
      {:ok, %{admin: true} = user} ->
        conn
        |> put_flash(:info, "Connexion administrateur réussie. Bienvenue #{user.username} !")
        |> AdminAuth.log_in_admin_user(user)

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

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Session administrateur déconnectée.")
    |> AdminAuth.log_out_admin_user()
  end
end
