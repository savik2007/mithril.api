defmodule Mithril.Mixfile do
  use Mix.Project

  def project do
    [
      version: "0.1.0",
      app: :mithril_api,
      description: "Add description to your package.",
      package: package(),
      elixir: "~> 1.8.1",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test],
      docs: [source_ref: "v#\{@version\}", main: "readme", extras: ["../../README.md"]]
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [extra_applications: [:logger, :runtime_tools], mod: {Mithril, []}]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:nex_json_schema, "~> 0.8"},
      {:confex, "~> 3.2"},
      {:cowboy, "~> 1.1"},
      {:poison, "~> 3.1"},
      {:comeonin, ">= 0.0.0"},
      {:plug_logger_json, "~> 0.5"},
      {:mox, "~> 0.3", only: :test},
      {:core, in_umbrella: true}
    ]
  end

  # Settings for publishing in Hex package manager:
  defp package do
    [
      contributors: ["Edenlab"],
      maintainers: ["Edenlab"],
      licenses: ["LISENSE.md"],
      links: %{github: "https://github.com/edenlabllc/mithril.api"},
      files: ~w(lib LICENSE.md mix.exs README.md)
    ]
  end

  defp aliases do
    [
      "ecto.setup": &ecto_setup/1,
      "ecto.migrate": &ecto_migrate/1,
      test: ["ecto.setup", "test"]
    ]
  end

  defp ecto_setup(_) do
    Mix.shell().cmd("cd ../core && mix ecto.setup && cd ../mithril_api")
  end

  defp ecto_migrate(_) do
    Mix.shell().cmd("cd ../core && mix ecto.migrate && cd ../mithril_api")
  end
end
