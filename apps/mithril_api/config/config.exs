# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :mithril_api,
  namespace: Mithril,
  sensitive_data_in_response: {:system, :boolean, "SENSITIVE_DATA_IN_RESPONSE_ENABLED", false}

config :mithril_api, :generators,
  migration: false,
  binary_id: true,
  sample_binary_id: "11111111-1111-1111-1111-111111111111"

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

import_config "#{Mix.env()}.exs"
