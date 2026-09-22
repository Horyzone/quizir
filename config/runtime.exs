import Config

# Load environment variables from .env files if present
cond do
  Code.ensure_loaded?(Quizir.Env) ->
    Quizir.Env.load(config_env: config_env())

  File.exists?(Path.expand("../lib/quizir/env.ex", __DIR__)) ->
    Code.eval_file(Path.expand("../lib/quizir/env.ex", __DIR__))
    Quizir.Env.load(config_env: config_env())

  true ->
    :ok
end

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/quizir start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :quizir, QuizirWeb.Endpoint, server: true
end

config :quizir, QuizirWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :dev do
  # Reload browser tabs when matching files change.
  config :quizir, QuizirWeb.Endpoint,
    live_reload: [
      web_console_logger: true,
      patterns: [
        # Static assets, except user uploads
        ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$",
        # Gettext translations
        ~r"priv/gettext/.*\.po$",
        # Router, Controllers, LiveViews and LiveComponents
        ~r"lib/quizir_web/router\.ex$",
        ~r"lib/quizir_web/(controllers|live|components)/.*\.(ex|heex)$"
      ]
    ]
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :quizir, Quizir.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :quizir, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :quizir, QuizirWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://bandit.hexdocs.pm/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :quizir, QuizirWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://plug.hexdocs.pm/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :quizir, QuizirWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production, configure SMTP via environment variables (SMTP_HOST, SMTP_PORT, etc.).
  # Swoosh is configured below if SMTP_HOST is present.
end

# ## SMTP Server & Mail Configuration
# Configures Swoosh with Swoosh.Adapters.SMTP whenever SMTP_HOST (or SMTP_SERVER / SMTP_RELAY) is set.
# Preserves the test adapter in :test environment.
if config_env() != :test do
  # Mail sender identity (for password reset, notifications, etc.)
  config :quizir,
    mail_from_name:
      System.get_env("SMTP_FROM_NAME") || System.get_env("MAIL_FROM_NAME") || "Quizir",
    mail_from_address:
      System.get_env("SMTP_FROM_EMAIL") || System.get_env("MAIL_FROM_ADDRESS") ||
        "contact@quizir.app"

  smtp_host =
    System.get_env("SMTP_HOST") ||
      System.get_env("SMTP_SERVER") ||
      System.get_env("SMTP_RELAY")

  if smtp_host do
    port_str = System.get_env("SMTP_PORT") || "587"
    smtp_port = String.to_integer(port_str)
    smtp_username = System.get_env("SMTP_USERNAME") || System.get_env("SMTP_USER")
    smtp_password = System.get_env("SMTP_PASSWORD") || System.get_env("SMTP_PASS")

    # SSL is true on port 465 (SMTPS), false on port 587 (STARTTLS) / port 25
    default_ssl = smtp_port == 465

    smtp_ssl =
      case System.get_env("SMTP_SSL") do
        val when val in ~w(true 1 TRUE) -> true
        val when val in ~w(false 0 FALSE) -> false
        _ -> default_ssl
      end

    smtp_tls =
      case System.get_env("SMTP_TLS") do
        "always" -> :always
        "never" -> :never
        _ -> :if_available
      end

    smtp_auth =
      case System.get_env("SMTP_AUTH") do
        "always" -> :always
        "never" -> :never
        _ -> if(smtp_username, do: :always, else: :if_available)
      end

    smtp_retries =
      case System.get_env("SMTP_RETRIES") do
        nil -> 1
        retries -> String.to_integer(retries)
      end

    ssl_verify =
      case System.get_env("SMTP_TLS_VERIFY") do
        val when val in ~w(none false 0 FALSE) -> :verify_none
        _ -> :verify_peer
      end

    cacerts =
      try do
        :public_key.cacerts_get()
      rescue
        _ -> []
      end

    tls_opts = [
      verify: ssl_verify,
      depth: 10,
      server_name_indication: String.to_charlist(smtp_host)
    ]

    tls_opts =
      if ssl_verify == :verify_peer and is_list(cacerts) and cacerts != [] do
        tls_opts ++
          [
            cacerts: cacerts,
            customize_hostname_check: [
              match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
            ]
          ]
      else
        tls_opts
      end

    mailer_config = [
      adapter: Swoosh.Adapters.SMTP,
      relay: smtp_host,
      port: smtp_port,
      ssl: smtp_ssl,
      tls: smtp_tls,
      auth: smtp_auth,
      retries: smtp_retries,
      sockopts: tls_opts,
      tls_options: tls_opts
    ]

    mailer_config =
      if smtp_username do
        mailer_config ++ [username: smtp_username, password: smtp_password || ""]
      else
        mailer_config
      end

    config :quizir, Quizir.Mailer, mailer_config
  end
end
