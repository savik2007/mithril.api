# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :core,
  namespace: Core,
  ecto_repos: [Core.Repo],
  trusted_clients: {:system, :list, "TRUSTED_CLIENT_IDS", []},
  api_resolvers: [
    sms: Core.API.SMS,
    mpi: Core.API.MPI,
    digital_signature: Core.API.Signature,
    recaptcha: Core.ReCAPTCHA
  ]

# Configure your database
config :core, Core.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: {:system, "DB_NAME", "mithril_api_dev"},
  username: {:system, "DB_USER", "postgres"},
  password: {:system, "DB_PASSWORD", "postgres"},
  hostname: {:system, "DB_HOST", "localhost"},
  port: {:system, :integer, "DB_PORT", 5432},
  loggers: [{Core.Ecto.LoggerJSON, :log, [:info]}]

# Configures Guardian
config :core,
  jwt_secret: {:system, "JWT_SECRET"},
  ttl_login: {:system, :integer, "JWT_LOGIN_TTL"}

config :core, Core.Guardian,
  issuer: "EHealth",
  secret_key: {Confex, :fetch_env!, [:core, :jwt_secret]}

config :core,
  ecto_repos: [Core.Repo]

# Core env
config :core, :password,
  expiration: {:system, :integer, "PASSWORD_EXPIRATION_DAYS", 90},
  max_failed_logins: {:system, :integer, "MAX_FAILED_LOGINS", 10},
  # minutes
  max_failed_logins_period: {:system, :integer, "MAX_FAILED_LOGINS_PERIOD", 10}

config :core, :"2fa",
  user_2fa_enabled?: {:system, :boolean, "USER_2FA_ENABLED", true},
  sms_enabled?: {:system, :boolean, "SMS_ENABLED", true},
  # minutes
  otp_send_timeout: {:system, :integer, "OTP_SEND_TIMEOUT", 1},
  otp_send_counter_max: {:system, :integer, "OTP_SEND_COUNTER_MAX", 3},
  user_otp_error_max: {:system, :integer, "USER_OTP_ERROR_MAX", 3},
  # seconds
  otp_ttl: {:system, :integer, "OTP_LIFETIME", 300},
  otp_length: {:system, :integer, "OTP_LENGTH", 6},
  otp_max_attempts: {:system, :integer, "OTP_MAX_ATTEMPTS", 3},
  otp_sms_template: {:system, :string, "OTP_SMS_TEMPLATE", "Код підтвердження: <otp.code>"}

config :core, :token_lifetime, %{
  code: {:system, :integer, "AUTH_CODE_GRANT_LIFETIME", 5 * 60},
  access: {:system, :integer, "AUTH_ACCESS_TOKEN_LIFETIME", 30 * 24 * 60 * 60},
  refresh: {:system, :integer, "AUTH_REFRESH_TOKEN_LIFETIME", 7 * 24 * 60 * 60}
}

config :core, Core.ReCAPTCHA,
  url: {:system, "RECAPTCHA_VERIFY_URL", "https://www.google.com/recaptcha/api/siteverify"},
  secret: {:system, "RECAPTCHA_SECRET"}

# Configures MPI API
config :core, Core.API.MPI,
  endpoint: {:system, "MPI_ENDPOINT"},
  hackney_options: [
    connect_timeout: {:system, :integer, "MPI_REQUEST_TIMEOUT", 30_000},
    recv_timeout: {:system, :integer, "MPI_REQUEST_TIMEOUT", 30_000},
    timeout: {:system, :integer, "MPI_REQUEST_TIMEOUT", 30_000}
  ]

# Configures Digital Signature API
config :core, Core.API.Signature,
  enabled: {:system, :boolean, "DIGITAL_SIGNATURE_ENABLED", false},
  endpoint: {:system, "DIGITAL_SIGNATURE_ENDPOINT"},
  hackney_options: [
    connect_timeout: {:system, :integer, "DIGITAL_SIGNATURE_REQUEST_TIMEOUT", 30_000},
    recv_timeout: {:system, :integer, "DIGITAL_SIGNATURE_REQUEST_TIMEOUT", 30_000},
    timeout: {:system, :integer, "DIGITAL_SIGNATURE_REQUEST_TIMEOUT", 30_000}
  ]

# Configures OTP Verification API
config :core, Core.API.SMS,
  endpoint: {:system, "OTP_ENDPOINT"},
  hackney_options: [
    connect_timeout: {:system, :integer, "OTP_REQUEST_TIMEOUT", 30_000},
    recv_timeout: {:system, :integer, "OTP_REQUEST_TIMEOUT", 30_000},
    timeout: {:system, :integer, "OTP_REQUEST_TIMEOUT", 30_000}
  ]

config :phoenix, :json_library, Jason

import_config "#{Mix.env()}.exs"
