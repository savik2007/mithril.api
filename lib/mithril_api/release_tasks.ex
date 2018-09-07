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
    start_services()

    run_migrations()

    shutdown()
  end

  def seed do
    start_services()

    seed_script = seed_path()
    IO.puts("Looking for seed script..")

    if File.exists?(seed_script) do
      IO.puts("Running seed script..")
      Code.eval_file(seed_script)
    end

    shutdown()
  end

  defp start_services do
    IO.puts("Starting dependencies..")
    # Start apps necessary for executing migrations
    Enum.each(@start_apps, &Application.ensure_all_started/1)

    # Start the Repo(s) for app
    IO.puts("Starting repos..")
    Enum.each(@repos, & &1.start_link(pool_size: 1))
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

  defp run_migrations do
    Enum.each(@repos, &run_migrations_for/1)
  end

  defp run_migrations_for(repo) do
    app = Keyword.get(repo.config, :otp_app)
    IO.puts("Running migrations for #{app}")
    Ecto.Migrator.run(repo, migrations_path(), :up, all: true)
  end

  defp migrations_path, do: Application.app_dir(:mithril_api, "priv/repo/migrations")
  defp seed_path, do: Application.app_dir(:mithril_api, "priv/repo/seeds.exs")
end
