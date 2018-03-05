defmodule Mithril.API.SMSBehaviour do
  @moduledoc false

  @callback send(phone_number :: binary, body :: binary, type :: binary) ::
              {:ok, result :: term}
              | {:error, reason :: term}
end
