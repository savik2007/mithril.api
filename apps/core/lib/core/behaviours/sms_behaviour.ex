defmodule Core.API.SMSBehaviour do
  @moduledoc false

  @callback send(phone_number :: binary, body :: binary, type :: binary) ::
              {:ok, result :: term}
              | {:error, reason :: term}

  @callback verifications(phone_number :: binary, headers :: list) ::
              {:ok, result :: term}
              | {:error, reason :: term}
end
