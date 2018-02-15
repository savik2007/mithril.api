defmodule Mithril.OTP.SMSBehaviour do
  @moduledoc false

  @callback send(phone_number :: term, body :: term, type :: term) ::
              {:ok, result :: term}
              | {:error, reason :: term}
end
