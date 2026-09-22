defmodule Quizir.Accounts.UserNotifier do
  require Logger
  import Swoosh.Email

  alias Quizir.Mailer

  @doc """
  Delivers the instructions to reset a password.
  """
  def deliver_reset_password_instructions(user, url) do
    if user.email do
      from_name = Application.get_env(:quizir, :mail_from_name, "Quizir")
      from_email = Application.get_env(:quizir, :mail_from_address, "contact@quizir.app")

      email =
        new()
        |> to({user.username, user.email})
        |> from({from_name, from_email})
        |> subject("Réinitialisation de votre mot de passe Quizir")
        |> text_body("""
        Bonjour #{user.username},

        Vous avez demandé la réinitialisation de votre mot de passe sur Quizir.
        Vous pouvez le réinitialiser en cliquant sur le lien ci-dessous :

        #{url}

        Si vous n'avez pas demandé cette réinitialisation, veuillez ignorer cet email.
        Ce lien expire dans 2 heures.

        L'équipe Quizir
        """)
        |> html_body("""
        <!DOCTYPE html>
        <html>
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Réinitialisation de votre mot de passe</title>
          </head>
          <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f4f4f5; margin: 0; padding: 24px; color: #18181b;">
            <table align="center" border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width: 560px; background-color: #ffffff; border-radius: 16px; border: 1px solid #e4e4e7; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);">
              <tr>
                <td style="padding: 32px 32px 20px 32px; text-align: center; border-bottom: 1px solid #f4f4f5;">
                  <span style="font-size: 26px; font-weight: 800; color: #4f46e5; letter-spacing: -0.5px;">Quizir</span>
                </td>
              </tr>
              <tr>
                <td style="padding: 32px;">
                  <h2 style="margin: 0 0 16px; font-size: 20px; font-weight: 700; color: #18181b;">Bonjour #{user.username},</h2>
                  <p style="margin: 0 0 16px; font-size: 15px; line-height: 24px; color: #3f3f46;">
                    Vous avez demandé la réinitialisation de votre mot de passe sur Quizir.
                  </p>
                  <p style="margin: 0 0 24px; font-size: 15px; line-height: 24px; color: #3f3f46;">
                    Cliquez sur le bouton ci-dessous pour choisir un nouveau mot de passe :
                  </p>
                  <table border="0" cellpadding="0" cellspacing="0" width="100%" style="margin-bottom: 24px;">
                    <tr>
                      <td align="center">
                        <a href="#{url}" target="_blank" style="display: inline-block; background-color: #4f46e5; color: #ffffff; text-decoration: none; padding: 14px 28px; border-radius: 10px; font-size: 15px; font-weight: 600; text-align: center;">
                          Réinitialiser mon mot de passe
                        </a>
                      </td>
                    </tr>
                  </table>
                  <p style="margin: 0 0 8px; font-size: 13px; color: #71717a;">
                    Si le bouton ne fonctionne pas, copiez et collez ce lien dans votre navigateur :
                  </p>
                  <p style="margin: 0 0 24px; font-size: 13px; word-break: break-all; color: #4f46e5;">
                    <a href="#{url}" style="color: #4f46e5; text-decoration: underline;">#{url}</a>
                  </p>
                  <hr style="border: none; border-top: 1px solid #e4e4e7; margin: 24px 0;" />
                  <p style="margin: 0 0 8px; font-size: 12px; color: #a1a1aa; line-height: 18px;">
                    Si vous n'êtes pas à l'origine de cette demande, vous pouvez ignorer cet email en toute sécurité. Votre mot de passe restera inchangé.
                  </p>
                  <p style="margin: 0; font-size: 12px; color: #a1a1aa; line-height: 18px;">
                    Ce lien expirera automatiquement dans 2 heures.
                  </p>
                </td>
              </tr>
            </table>
          </body>
        </html>
        """)

      mailer_config = Application.get_env(:quizir, Mailer, [])
      adapter = Keyword.get(mailer_config, :adapter, Swoosh.Adapters.Local)
      relay = Keyword.get(mailer_config, :relay, "localhost")
      port = Keyword.get(mailer_config, :port, "default")

      Logger.info(
        "[Mailer] Sending password reset instructions to #{user.email} (username: #{user.username}) " <>
          "using #{inspect(adapter)} via #{relay}:#{port}"
      )

      case Mailer.deliver(email) do
        {:ok, metadata} ->
          Logger.info(
            "[Mailer] Password reset email successfully delivered to #{user.email}! (metadata: #{inspect(metadata)})"
          )

          {:ok, email}

        {:error, reason} = error ->
          Logger.error(
            "[Mailer] Failed to deliver password reset email to #{user.email}!\n" <>
              "  Adapter: #{inspect(adapter)}\n" <>
              "  Relay: #{relay}:#{port}\n" <>
              "  From: #{from_name} <#{from_email}>\n" <>
              "  Error: #{format_error(reason)}\n" <>
              "  Raw reason: #{inspect(reason, pretty: true)}"
          )

          error
      end
    else
      Logger.warning(
        "[Mailer] Cannot send password reset instructions: user '#{user.username}' has no email address configured."
      )

      {:error, :no_email}
    end
  end

  @doc """
  Formats an email delivery error into a human-readable diagnosis string.
  """
  def format_error({:retries_exceeded, {:network_failure, host, {:error, reason}}}) do
    "Network failure connecting to #{host}: #{format_error(reason)}"
  end

  def format_error({:options, :incompatible, details}) do
    "Incompatible SSL/TLS options: #{inspect(details)}. Check SMTP_SSL, SMTP_PORT, or SMTP_TLS_VERIFY settings."
  end

  def format_error({:tls_alert, {:handshake_failure, details}}) do
    "TLS handshake failure: #{inspect(details)}. Certificate or cipher mismatch between client and server."
  end

  def format_error({:bad_cert, :max_path_length_reached}) do
    "SSL certificate validation error (max_path_length_reached): intermediate CA certificate chain length exceeded."
  end

  def format_error({:bad_cert, reason}) do
    "SSL certificate validation error: #{inspect(reason)}. Check SMTP certificate or set SMTP_TLS_VERIFY=none."
  end

  def format_error({:permanent_failure, host, reason}) do
    "Permanent SMTP server rejection from #{host}: #{inspect(reason)}"
  end

  def format_error({:temporary_failure, host, reason}) do
    "Temporary SMTP server error from #{host}: #{inspect(reason)}"
  end

  def format_error(reason) when is_binary(reason), do: reason
  def format_error(reason), do: inspect(reason, pretty: true)
end
