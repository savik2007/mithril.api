# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure for your application as:
#
#     config :mithril_api, key: :value
#
# And access this configuration in your application as:
#
#     Application.get_env(:mithril_api, :key)
#
# Or configure a 3rd-party app:
#
#     config :logger, level: :info
#
# Or read environment variables in runtime (!) as:
#
#     :var_name, "${ENV_VAR_NAME}"

config :mithril_api,
  ecto_repos: [Mithril.Repo],
  namespace: Mithril

# Configure your database
config :mithril_api, Mithril.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: {:system, "DB_NAME", "mithril_api_dev"},
  username: {:system, "DB_USER", "postgres"},
  password: {:system, "DB_PASSWORD", "postgres"},
  hostname: {:system, "DB_HOST", "localhost"},
  port: {:system, :integer, "DB_PORT", 5432},
  loggers: [{Ecto.LoggerJSON, :log, [:info]}]

config :mithril_api, :generators,
  migration: false,
  binary_id: true,
  sample_binary_id: "11111111-1111-1111-1111-111111111111"

config :mithril_api, :password,
  expiration: {:system, :integer, "PASSWORD_EXPIRATION_DAYS", 90}

config :mithril_api, :"2fa",
  user_2fa_enabled?: {:system, :boolean, "USER_2FA_ENABLED", true},
  sms_enabled?: {:system, :boolean, "SMS_ENABLED", false},
  otp_send_timeout: {:system, :integer, "OTP_SEND_TIMEOUT", 60}, # seconds
  otp_send_counter_max: {:system, :integer, "OTP_SEND_COUNTER_MAX", 3},
  user_login_error_max: {:system, :integer, "USER_LOGIN_ERROR_MAX", 3},
  user_otp_error_max: {:system, :integer, "USER_OTP_ERROR_MAX", 3},
  otp_ttl: {:system, :integer, "OTP_LIFETIME", 300}, # seconds
  otp_length: {:system, :integer, "OTP_LENGTH", 6},
  otp_max_attempts: {:system, :integer, "OTP_MAX_ATTEMPTS", 3},
  otp_sms_template: {:system, :string, "OTP_SMS_TEMPLATE", "Код підтвердження: <otp.code>"}

# Configures the endpoint
config :mithril_api, Mithril.Web.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "6sOsW9uKv+8o8y/hIA3F4dNkJE2O35e2l6SaS9P/xW0+Nh9Fo59T6JHnl0GzBmio",
  render_errors: [view: EView.Views.PhoenixError, accepts: ~w(json)]

# Configures Elixir's Logger
config :logger, :console,
  format: "$message\n",
  handle_otp_reports: true,
  level: :info

config :mithril_api, :token_lifetime, %{
  code: {:system, "AUTH_CODE_GRANT_LIFETIME", 5 * 60},
  access: {:system, "AUTH_ACCESS_TOKEN_LIFETIME", 30 * 24 * 60 * 60},
  refresh: {:system, "AUTH_REFRESH_TOKEN_LIFETIME", 7 * 24 * 60 * 60}
}

# Configures employee request terminator
config :mithril_api, Mithril.OTP.Terminator,
  frequency: 60 * 60 * 1000 # every hour

# Configures OTP Verification API
config :mithril_api, Mithril.OTP.SMS,
  endpoint: {:system, "OTP_ENDPOINT"},
  hackney_options: [
    connect_timeout: {:system, :integer, "OTP_REQUEST_TIMEOUT", 30_000},
    recv_timeout: {:system, :integer, "OTP_REQUEST_TIMEOUT", 30_000},
    timeout: {:system, :integer, "OTP_REQUEST_TIMEOUT", 30_000}
  ]

config :mithril_api, Mithril.Scheduler,
  token_expiration: {:system, :string, "TOKEN_EXPIRATION_SCHEDULE", "* 0-4 * * *"}

import_config "#{Mix.env}.exs"
