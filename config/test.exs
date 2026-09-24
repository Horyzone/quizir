import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :quizir, Quizir.Repo,
  username: System.get_env("POSTGRES_USER") || "quizir",
  password: System.get_env("POSTGRES_PASSWORD") || "quizir",
  hostname: System.get_env("POSTGRES_HOST") || "127.0.0.1",
  database: "quizir_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :quizir, QuizirWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "2Vio84FkspWhR8q4YFXjIr2jysgj5JznBGeIyyO2EiaWmHXFZahO6p7omyjyNeQx",
  server: false

# In test we don't send emails
config :quizir, Quizir.Mailer, adapter: Swoosh.Adapters.Test

# Fast password hashing in tests
config :pbkdf2_elixir, :rounds, 1

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Disable automatic redirect in test suite to allow isolated sandbox tests
config :quizir, :force_initial_admin_setup, false

# Disable S3 upload by default in test suite
config :quizir, :s3_configured_override, false
