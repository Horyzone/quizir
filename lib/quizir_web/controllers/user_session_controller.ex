defmodule QuizirWeb.UserSessionController do
  use QuizirWeb, :controller

  alias Quizir.Accounts
  alias QuizirWeb.UserAuth

  def create(conn, %{"user" => user_params}) do
    %{"username" => username, "password" => password} = user_params

    if user = Accounts.get_user_by_username_and_password(username, password) |> unwrap_user() do
      if user.totp_enabled do
        conn
        |> put_session(:totp_auth_user_id, user.id)
        |> put_session(:totp_auth_remember_me, user_params["remember_me"] == "true")
        |> redirect(to: ~p"/users/two_factor")
      else
        welcome_msg =
          if user.admin do
            "Bienvenue #{user.username} ! Votre compte administrateur est prêt."
          else
            "Bienvenue #{user.username} !"
          end

        conn
        |> put_flash(:info, welcome_msg)
        |> UserAuth.log_in_user(user, user_params)
      end
    else
      # In order to prevent user enumeration attacks, don't disclose whether the username exists.
      conn
      |> put_flash(:error, "Nom d'utilisateur ou mot de passe incorrect.")
      |> put_flash(:username, String.slice(username, 0, 160))
      |> redirect(to: ~p"/users/log_in")
    end
  end

  def create_two_factor(conn, %{"totp" => %{"code" => code}}) do
    user_id = get_session(conn, :totp_auth_user_id)
    remember_me = get_session(conn, :totp_auth_remember_me)
    user = user_id && Accounts.get_user(user_id)

    if user && user.totp_enabled && Accounts.validate_user_totp(user, code) do
      welcome_msg =
        if user.admin do
          "Bienvenue #{user.username} ! Votre compte administrateur est prêt."
        else
          "Bienvenue #{user.username} !"
        end

      conn
      |> delete_session(:totp_auth_user_id)
      |> delete_session(:totp_auth_remember_me)
      |> put_flash(:info, welcome_msg)
      |> UserAuth.log_in_user(user, %{"remember_me" => to_string(remember_me)})
    else
      conn
      |> put_flash(:error, "Code de vérification 2FA invalide ou expiré.")
      |> redirect(to: ~p"/users/two_factor")
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
