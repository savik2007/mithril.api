defmodule Mithril.API.MPIBehaviour do
  @moduledoc false

  @callback search(params :: map, headers :: map) ::
              {:ok, result :: term}
              | {:error, reason :: term}
end
