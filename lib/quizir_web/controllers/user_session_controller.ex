defmodule QuizirWeb.UserSessionController do
  use QuizirWeb, :controller

  alias Quizir.Accounts
  alias QuizirWeb.UserAuth

  def create(conn, %{"user" => user_params}) do
    %{"username" => username, "password" => password} = user_params

    if user = Accounts.get_user_by_username_and_password(username, password) |> unwrap_user() do
      welcome_msg =
        if user.admin do
          "Bienvenue #{user.username} ! Votre compte administrateur est prêt."
        else
          "Bienvenue #{user.username} !"
        end

      conn
      |> put_flash(:info, welcome_msg)
      |> UserAuth.log_in_user(user, user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the username exists.
      conn
      |> put_flash(:error, "Nom d'utilisateur ou mot de passe incorrect.")
      |> put_flash(:username, String.slice(username, 0, 160))
      |> redirect(to: ~p"/users/log_in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Vous êtes maintenant déconnecté.")
    |> UserAuth.log_out_user()
  end

  defp unwrap_user({:ok, user}), do: user
  defp unwrap_user(_), do: nil
end
