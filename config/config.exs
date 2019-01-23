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
  namespace: Mithril,
  ecto_repos: [Mithril.Repo],
  system_user: {:system, "EHEALTH_SYSTEM_USER", "4261eacf-8008-4e62-899f-de1e2f7065f0"},
  sensitive_data_in_response: {:system, :boolean, "SENSITIVE_DATA_IN_RESPONSE_ENABLED", false},
  trusted_clients: {:system, :list, "TRUSTED_CLIENT_IDS", []},
  api_resolvers: [
    sms: Mithril.API.SMS,
    mpi: Mithril.API.MPI,
    digital_signature: Mithril.API.Signature
  ],
  token_ttl_after_expiration: {:system, :integer, "TOKEN_TTL_AFTER_EXPIRATION_DAYS", 30}

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

config :mithril_api, Mithril.TokenAPI.Deactivator, limit: 500

config :mithril_api, :password,
  expiration: {:system, :integer, "PASSWORD_EXPIRATION_DAYS", 90},
  max_failed_logins: {:system, :integer, "MAX_FAILED_LOGINS", 10},
  # minutes
  max_failed_logins_period: {:system, :integer, "MAX_FAILED_LOGINS_PERIOD", 10}

config :mithril_api, :"2fa",
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

# Configures Guardian
config :mithril_api,
  jwt_secret: {:system, "JWT_SECRET"},
  ttl_login: {:system, :integer, "JWT_LOGIN_TTL"}

config :mithril_api, Mithril.Guardian,
  issuer: "EHealth",
  secret_key: {Confex, :fetch_env!, [:mithril_api, :jwt_secret]}

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
  code: {:system, :integer, "AUTH_CODE_GRANT_LIFETIME", 5 * 60},
  access: {:system, :integer, "AUTH_ACCESS_TOKEN_LIFETIME", 30 * 24 * 60 * 60},
  refresh: {:system, :integer, "AUTH_REFRESH_TOKEN_LIFETIME", 7 * 24 * 60 * 60}
}

# Configures OTP Verification API
config :mithril_api, Mithril.API.SMS,
  endpoint: {:system, "OTP_ENDPOINT"},
  hackney_options: [
    connect_timeout: {:system, :integer, "OTP_REQUEST_TIMEOUT", 30_000},
    recv_timeout: {:system, :integer, "OTP_REQUEST_TIMEOUT", 30_000},
    timeout: {:system, :integer, "OTP_REQUEST_TIMEOUT", 30_000}
  ]

# Configures MPI API
config :mithril_api, Mithril.API.MPI,
  endpoint: {:system, "MPI_ENDPOINT"},
  hackney_options: [
    connect_timeout: {:system, :integer, "MPI_REQUEST_TIMEOUT", 30_000},
    recv_timeout: {:system, :integer, "MPI_REQUEST_TIMEOUT", 30_000},
    timeout: {:system, :integer, "MPI_REQUEST_TIMEOUT", 30_000}
  ]

# Configures Digital Signature API
config :mithril_api, Mithril.API.Signature,
  enabled: {:system, :boolean, "DIGITAL_SIGNATURE_ENABLED", false},
  endpoint: {:system, "DIGITAL_SIGNATURE_ENDPOINT"},
  hackney_options: [
    connect_timeout: {:system, :integer, "DIGITAL_SIGNATURE_REQUEST_TIMEOUT", 30_000},
    recv_timeout: {:system, :integer, "DIGITAL_SIGNATURE_REQUEST_TIMEOUT", 30_000},
    timeout: {:system, :integer, "DIGITAL_SIGNATURE_REQUEST_TIMEOUT", 30_000}
  ]

config :mithril_api, Mithril.Scheduler,
  token_expiration: {:system, :string, "TOKEN_EXPIRATION_SCHEDULE", "* 0-4 * * *"},
  token_deleting: {:system, :string, "TOKEN_DELETING_SCHEDULE", "* 1-4 * * *"},
  otp_expiration: {:system, :string, "OTP_EXPIRATION_SCHEDULE", "*/5 * * * *"}

config :git_ops,
  mix_project: Mithril.Mixfile,
  changelog_file: "CHANGELOG.md",
  repository_url: "https://github.com/edenlabllc/mithril.api/",
  types: [
    # Makes an allowed commit type called `tidbit` that is not
    # shown in the changelog
    tidbit: [
      hidden?: true
    ],
    # Makes an allowed commit type called `important` that gets
    # a section in the changelog with the header "Important Changes"
    important: [
      header: "Important Changes"
    ]
  ],
  # Instructs the tool to manage your mix version in your `mix.exs` file
  # See below for more information
  manage_mix_version?: true,
  # Instructs the tool to manage the version in your README.md
  # Pass in `true` to use `"README.md"` or a string to customize
  manage_readme_version: "README.md"

import_config "#{Mix.env()}.exs"
