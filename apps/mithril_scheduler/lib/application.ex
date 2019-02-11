defmodule MithrilScheduler do
  @moduledoc """
  This is an entry point of mithril_scheduler application.
  """
  use Application
  alias Confex.Resolver
  alias MithrilScheduler.Scheduler
  alias MithrilScheduler.TokenAPI.Deactivator

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Deactivator, [:token_deactivator], id: :token_deactivator),
      worker(Deactivator, [:token_cleaner], id: :token_cleaner),
      worker(Scheduler, [])
    ]

    opts = [strategy: :one_for_one, name: MithrilScheduler.Supervisor]
    result = Supervisor.start_link(children, opts)
    Scheduler.create_jobs()
    {:ok, _} = result
  end

  # Loads configuration in `:init` callbacks and replaces `{:system, ..}` tuples via Confex
  @doc false
  def init(_key, config) do
    Resolver.resolve(config)
  end
end
