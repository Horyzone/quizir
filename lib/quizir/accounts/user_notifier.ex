defmodule Quizir.Accounts.UserNotifier do
  import Swoosh.Email

  alias Quizir.Mailer

  @doc """
  Delivers the instructions to reset a password.
  """
  def deliver_reset_password_instructions(user, url) do
    if user.email do
      email =
        new()
        |> to({user.username, user.email})
        |> from({"Quizir", "contact@quizir.app"})
        |> subject("Réinitialisation de votre mot de passe Quizir")
        |> text_body("""
        Bonjour #{user.username},

        Vous avez demandé la réinitialisation de votre mot de passe sur Quizir.
        Vous pouvez le réinitialiser en cliquant sur le lien ci-dessous :

        #{url}

        Si vous n'avez pas demandé cette réinitialisation, veuillez ignorer cet email.
        Ce lien expire dans 2 heures.
        """)

      with {:ok, _metadata} <- Mailer.deliver(email) do
        {:ok, email}
      end
    else
      {:error, :no_email}
    end
  end
end
