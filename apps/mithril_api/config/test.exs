use Mix.Config

# Configuration for test environment
config :ex_unit, capture_log: true

config :mithril_api,
  sql_sandbox: true,
  sensitive_data_in_response: {:system, :boolean, "SENSITIVE_DATA_IN_RESPONSE_ENABLED", true}

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :mithril_api, Mithril.Web.Endpoint,
  http: [port: 4001],
  server: true

# Print only warnings and errors during test
config :logger, level: :error

config :bcrypt_elixir, :log_rounds, 4

config :mithril_api, :"2fa",
  otp_ttl: 1,
  user_2fa_enabled?: {:system, :boolean, "USER_2FA_ENABLED", true},
  sms_enabled?: {:system, :boolean, "SMS_ENABLED", false},
  # minutes
  otp_send_timeout: {:system, :integer, "OTP_SEND_TIMEOUT", 0}
