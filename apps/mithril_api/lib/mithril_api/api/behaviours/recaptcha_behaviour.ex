defmodule Mithril.API.ReCAPTCHABehaviour do
  @moduledoc false

  @callback verify_token(body :: binary) :: {:ok, result :: term} | {:error, reason :: term}
end
