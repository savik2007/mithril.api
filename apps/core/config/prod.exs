use Mix.Config
# Configure your database
config :core, Core.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: {:system, "DB_NAME"},
  username: {:system, "DB_USER"},
  password: {:system, "DB_PASSWORD"},
  hostname: {:system, "DB_HOST"},
  port: {:system, :integer, "DB_PORT"},
  pool_size: {:system, :integer, "DB_POOL_SIZE", 10}
