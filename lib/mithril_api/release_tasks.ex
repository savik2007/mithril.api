defmodule Mithril.ReleaseTasks do
  @moduledoc """
  Nice way to apply migrations inside a released application.

  Example:

      mithril_api/bin/mithril_api command Elixir.Mithril.ReleaseTasks migrate
  """
  alias Ecto.Migrator

  @start_apps [
    :logger,
    :logger_json,
    :postgrex,
    :ecto
  ]

  @apps [
    :mithril_api
  ]

  @repos [
    Mithril.Repo
  ]

  def migrate do
    load_app()
    start_repos()

    # Run migrations
    Enum.each(@apps, &run_migrations_for/1)

    shutdown()
  end

  def seed do
    load_app()
    start_repos()

    seed_script = seed_path()
    IO.puts("Looking for seed script..")

    if File.exists?(seed_script) do
      IO.puts("Running seed script..")
      Code.eval_file(seed_script)
    end

    shutdown()
  end

  defp load_app do
    IO.puts("Loading mithril_api..")
    # Load the code for mithril_api, but don't start it
    :ok = Application.load(:mithril_api)

    IO.puts("Starting dependencies..")
    # Start apps necessary for executing migrations
    Enum.each(@start_apps, &Application.ensure_all_started/1)
  end

  defp start_repos do
    IO.puts("Starting repos..")
    Enum.each(@repos, & &1.start_link(pool_size: 1))
  end

  defp shutdown do
    IO.puts("Success!")
    System.halt(0)
    :init.stop()
  end

  defp run_migrations_for(app) do
    IO.puts("Running migrations for #{app}")
    Enum.each(@repos, &Migrator.run(&1, migrations_path(), :up, all: true))
  end

  defp migrations_path, do: Application.app_dir(:mithril_api, "priv/repo/migrations")
  defp seed_path, do: Application.app_dir(:mithril_api, "priv/repo/seeds.exs")
end
