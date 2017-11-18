defmodule Mithril do
  @moduledoc """
  This is an entry point of mithril_api application.
  """
  use Application
  alias Mithril.Web.Endpoint
  alias Confex.Resolver

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = [
      # Start the Ecto repository
      supervisor(Mithril.Repo, []),
      # Start the endpoint when the application starts
      supervisor(Endpoint, []),
      supervisor(Mithril.OTP.Terminator, []),
      # Starts a worker by calling: Mithril.Worker.start_link(arg1, arg2, arg3)
      # worker(Mithril.Worker, [arg1, arg2, arg3]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Mithril.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Endpoint.config_change(changed, removed)
    :ok
  end

  # Loads configuration in `:init` callbacks and replaces `{:system, ..}` tuples via Confex
  @doc false
  def init(_key, config) do
    Resolver.resolve(config)
  end
end
