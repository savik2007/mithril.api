defmodule Mithril.MixProject do
  use Mix.Project

  @version "3.3.3"
  def project do
    [
      version: @version,
      apps_path: "apps",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    [
      {:distillery, "~> 2.0", runtime: false},
      {:excoveralls, "~> 0.10", only: [:dev, :test]},
      {:credo, "~> 0.9", only: [:dev, :test]},
      {:git_ops, "~> 0.6.0", only: [:dev]}
    ]
  end
end
