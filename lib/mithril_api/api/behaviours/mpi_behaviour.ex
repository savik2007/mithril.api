defmodule Mithril.API.MPIBehaviour do
  @moduledoc false

  @callback person(id :: binary) :: {:ok, result :: term} | {:error, reason :: term}
end
