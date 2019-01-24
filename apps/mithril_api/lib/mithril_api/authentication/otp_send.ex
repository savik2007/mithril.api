defmodule Mithril.Authentication.OTPSend do
  @moduledoc false

  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field(:type, :string)
    field(:factor, :string)
  end
end
