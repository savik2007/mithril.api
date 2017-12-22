defmodule Mithril.Web.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build and query models.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      use Phoenix.ConnTest
      import Mithril.Web.ConnCase
      import MithrilWeb.Router.Helpers
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Mithril.Factory
      import Mithril.Test.Helpers
      alias Mithril.Repo

      # The default endpoint for testing
      @endpoint Mithril.Web.Endpoint
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Mithril.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Mithril.Repo, {:shared, self()})
    end

    conn =
      Phoenix.ConnTest.build_conn()
      |> Plug.Conn.put_req_header("content-type", "application/json")

    {:ok, conn: conn}
  end

  def start_microservices(module) do
    {:ok, port} = :gen_tcp.listen(0, [])
    {:ok, port_string} = :inet.port(port)
    :erlang.port_close(port)
    ref = make_ref()
    {:ok, _pid} = Plug.Adapters.Cowboy.http module, [], port: port_string, ref: ref # TODO: only 1 worker here
    {:ok, port_string, ref}
  end

  def stop_microservices(ref) do
    Plug.Adapters.Cowboy.shutdown(ref)
  end
end
