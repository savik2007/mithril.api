defmodule Mithril.API.MPIBehaviour do
  @moduledoc false

  @callback search(params :: map, headers :: list) ::
              {:ok, result :: term}
              | {:error, reason :: term}
end
