use Mix.Config

config :core,
  # Run acceptance test in concurrent mode
  trusted_clients: {:system, :list, "TRUSTED_CLIENT_IDS", ["30074b6e-fbab-4dc1-9d37-88c21dab1847"]},
  api_resolvers: [
    sms: SMSMock,
    mpi: MPIMock,
    recaptcha: ReCAPTCHAMock,
    digital_signature: SignatureMock
  ]

# Configure your database
config :core, Core.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  database: {:system, "DB_NAME", "mithril_api_test"}

config :core, Core.Guardian,
  issuer: "EHealth",
  secret_key: "some_super-sEcret"

config :core,
  # Run acceptance test in concurrent mode
  ttl_login: 1

config :core, :"2fa",
  otp_ttl: 1,
  user_2fa_enabled?: {:system, :boolean, "USER_2FA_ENABLED", true},
  sms_enabled?: {:system, :boolean, "SMS_ENABLED", false},
  # minutes
  otp_send_timeout: {:system, :integer, "OTP_SEND_TIMEOUT", 0}

config :logger, level: :error
