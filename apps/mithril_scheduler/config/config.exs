# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :mithril_scheduler, MithrilScheduler.Scheduler,
  token_expiration: {:system, :string, "TOKEN_EXPIRATION_SCHEDULE", "* 0-4 * * *"},
  token_deleting: {:system, :string, "TOKEN_DELETING_SCHEDULE", "* 1-4 * * *"},
  otp_expiration: {:system, :string, "OTP_EXPIRATION_SCHEDULE", "*/5 * * * *"}

config :mithril_scheduler,
  ecto_repos: [Core.Repo]

config :mithril_scheduler, MithrilScheduler.TokenAPI.Deactivator,
  limit: 500,
  token_ttl_after_expiration: {:system, :integer, "TOKEN_TTL_AFTER_EXPIRATION_DAYS", 30}

import_config "#{Mix.env()}.exs"
