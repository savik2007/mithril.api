defmodule Core.API.SignatureBehaviour do
  @moduledoc false

  @callback decode_and_validate(
              signed_content :: binary,
              signed_content_encoding :: binary,
              attrs :: map
            ) ::
              {:ok, result :: term}
              | {:error, reason :: term}
end
