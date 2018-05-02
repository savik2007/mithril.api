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

      def post_approval(conn, user_id, client_id, redirect_uri, scope) do
        payload = %{
          "app" => %{
            client_id: client_id,
            redirect_uri: redirect_uri,
            scope: scope
          }
        }

        raw_response =
          conn
          |> put_req_header("x-consumer-id", user_id)
          |> post(oauth2_app_path(conn, :authorize), payload)

        response = json_response(raw_response, 201)
        code_grant = get_in(response, ["data", "value"])
        redirect_uri = "http://localhost?code=#{code_grant}"

        assert redirect_uri == response["urgent"]["redirect_uri"]
        assert [^redirect_uri] = get_resp_header(raw_response, "location")

        code_grant
      end
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
end
