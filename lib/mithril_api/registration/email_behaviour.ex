defmodule Mithril.Registration.EmailBehaviour do
  @moduledoc false

  @callback send(email :: binary, verification_code :: binary) ::
              {:ok, result :: term}
              | {:error, reason :: term}
end
