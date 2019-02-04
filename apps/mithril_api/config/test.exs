use Mix.Config

# Configuration for test environment
config :ex_unit, capture_log: true

config :mithril_api,
  # Run acceptance test in concurrent mode
  sql_sandbox: true,
  sensitive_data_in_response: {:system, :boolean, "SENSITIVE_DATA_IN_RESPONSE_ENABLED", true},
  ttl_login: 1,
  trusted_clients: {:system, :list, "TRUSTED_CLIENT_IDS", ["30074b6e-fbab-4dc1-9d37-88c21dab1847"]},
  api_resolvers: [
    sms: SMSMock,
    mpi: MPIMock,
    digital_signature: SignatureMock
  ]

# Configure your database
config :mithril_api, Mithril.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  database: {:system, "DB_NAME", "mithril_api_test"}

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :mithril_api, Mithril.Web.Endpoint,
  http: [port: 4001],
  server: true

# Print only warnings and errors during test
config :logger, level: :error

config :bcrypt_elixir, :log_rounds, 4

config :mithril_api, Mithril.TokenAPI.Deactivator, limit: 1

config :mithril_api, :"2fa",
  otp_ttl: 1,
  user_2fa_enabled?: {:system, :boolean, "USER_2FA_ENABLED", true},
  sms_enabled?: {:system, :boolean, "SMS_ENABLED", false},
  # minutes
  otp_send_timeout: {:system, :integer, "OTP_SEND_TIMEOUT", 0}

config :mithril_api, Mithril.Guardian,
  issuer: "EHealth",
  secret_key: "some_super-sEcret"
