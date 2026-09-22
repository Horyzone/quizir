defmodule Mix.Tasks.Quizir.TestEmail do
  @moduledoc """
  Tests and diagnoses SMTP mail delivery configuration.

  ## Usage

      $ mix quizir.test_email <recipient_email>

  ## Example

      $ mix quizir.test_email dev@example.com
  """

  use Mix.Task
  import Swoosh.Email

  @shortdoc "Sends a test email to verify SMTP configuration"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    recipient = List.first(args)

    mailer_config = Application.get_env(:quizir, Quizir.Mailer, [])
    adapter = Keyword.get(mailer_config, :adapter, Swoosh.Adapters.Local)
    relay = Keyword.get(mailer_config, :relay, "localhost")
    port = Keyword.get(mailer_config, :port, 587)
    ssl = Keyword.get(mailer_config, :ssl, false)
    tls = Keyword.get(mailer_config, :tls, :if_available)
    auth = Keyword.get(mailer_config, :auth, :if_available)
    username = Keyword.get(mailer_config, :username)
    password_set? = Keyword.get(mailer_config, :password) not in [nil, ""]

    from_name = Application.get_env(:quizir, :mail_from_name, "Quizir")
    from_email = Application.get_env(:quizir, :mail_from_address, "contact@quizir.app")

    cacerts_count =
      try do
        cacerts = :public_key.cacerts_get()
        if is_list(cacerts), do: length(cacerts), else: 0
      rescue
        _ -> 0
      end

    Mix.shell().info("""
    ============================================================
    Quizir - Diagnostic de la configuration Mailer / SMTP
    ============================================================
    Adapter : #{inspect(adapter)}
    Relay   : #{relay}
    Port    : #{port}
    SSL     : #{inspect(ssl)}
    TLS     : #{inspect(tls)}
    Auth    : #{inspect(auth)}
    User    : #{username || "(aucun)"}
    Pass    : #{if password_set?, do: "[configuré]", else: "(non configuré)"}
    From    : #{from_name} <#{from_email}>
    CA certs: #{cacerts_count} certificats racine système trouvés
    ============================================================
    """)

    cond do
      is_nil(recipient) or recipient == "" ->
        Mix.shell().error("""
        [ERREUR] Aucun destinataire spécifié.

        Usage :
            mix quizir.test_email mon-adresse@example.com
        """)

      true ->
        Mix.shell().info("Envoi d'un email de test vers #{recipient} en cours...")

        timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

        email =
          new()
          |> to(recipient)
          |> from({from_name, from_email})
          |> subject("Quizir Test SMTP - #{timestamp}")
          |> text_body("""
          Ceci est un email de test envoyé par Quizir pour valider la configuration SMTP.

          Date d'envoi (UTC) : #{timestamp}
          Relay : #{relay}:#{port}
          Expéditeur : #{from_name} <#{from_email}>

          Si vous lisez ce message, votre configuration SMTP est parfaitement fonctionnelle !
          """)
          |> html_body("""
          <!DOCTYPE html>
          <html>
            <head><meta charset="utf-8"></head>
            <body style="font-family: sans-serif; padding: 24px; color: #18181b;">
              <h2 style="color: #4f46e5;">Quizir - Test de configuration SMTP</h2>
              <p>Ceci est un email de test envoyé depuis l'application Quizir.</p>
              <p><strong>Détails :</strong></p>
              <ul>
                <li><strong>Date (UTC) :</strong> #{timestamp}</li>
                <li><strong>Relay :</strong> #{relay}:#{port}</li>
                <li><strong>Expéditeur :</strong> #{from_name} &lt;#{from_email}&gt;</li>
              </ul>
              <p style="color: #16a34a; font-weight: bold;">
                Votre serveur SMTP et vos paramètres TLS sont correctement configurés.
              </p>
            </body>
          </html>
          """)

        case Quizir.Mailer.deliver(email) do
          {:ok, metadata} ->
            Mix.shell().info([
              :green,
              """
              ============================================================
              [SUCCÈS] Email envoyé avec succès à #{recipient} !
              Réponse du serveur SMTP :
              #{inspect(metadata, pretty: true)}
              ============================================================
              """
            ])

          {:error, reason} ->
            formatted_error = Quizir.Accounts.UserNotifier.format_error(reason)

            Mix.shell().error("""
            ============================================================
            [ÉCHEC] L'envoi de l'email a échoué.
            Erreur : #{formatted_error}

            Détails bruts de l'erreur :
            #{inspect(reason, pretty: true)}
            ============================================================
            Conseils de dépannage :
              - Si l'erreur mentionne un certificat SSL (max_path_length_reached, bad_cert) :
                Vérifiez que le port et le mode SSL (465 = SSL implicite, 587 = STARTTLS) correspondent.
                Vous pouvez tester avec SMTP_TLS_VERIFY=none dans .env si votre serveur utilise un certificat auto-signé.
              - Si l'erreur est une authentification (535, auth_failed) :
                Vérifiez votre SMTP_USERNAME et SMTP_PASSWORD dans .env.
              - Si l'erreur est un timeout ou network_failure :
                Vérifiez que le serveur SMTP #{relay} est accessible sur le port #{port} (pare-feu, blocage FAI).
            """)
        end
    end
  end
end
