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
#     config :trump_api, key: :value
#
# And access this configuration in your application as:
#
#     Application.get_env(:trump_api, :key)
#
# Or configure a 3rd-party app:
#
#     config :logger, level: :info
#
# Or read environment variables in runtime (!) as:
#
#     :var_name, "${ENV_VAR_NAME}"

config :trump_api,
  ecto_repos: [Trump.Repo],
  namespace: Trump

# Configure your database
config :trump_api, Trump.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: {:system, "DB_NAME", "trump_api_dev"},
  username: {:system, "DB_USER", "postgres"},
  password: {:system, "DB_PASSWORD", "postgres"},
  hostname: {:system, "DB_HOST", "localhost"},
  port: {:system, :integer, "DB_PORT", 5432}
# This configuration file is loaded before any dependency and
# is restricted to this project.

# Configures the endpoint
config :trump_api, Trump.Web.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "YfOapYVW+HP0fv/xObEFlLQ/nwr3BiUkTy+4WDjRzx7uTV/9b+QAm4TLABZdqLUI",
  render_errors: [view: EView.Views.PhoenixError, accepts: ~w(json)]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
config :trump_api, :generators,
  migration: false,
  binary_id: true,
  sample_binary_id: "11111111-1111-1111-1111-111111111111"

import_config "authable.exs"
import_config "#{Mix.env}.exs"
