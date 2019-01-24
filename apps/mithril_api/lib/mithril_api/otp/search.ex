defmodule Mithril.OTP.Search do
  @moduledoc false

  use Ecto.Schema

  alias Mithril.Ecto.StringLike

  @primary_key false
  embedded_schema do
    field(:key, StringLike)
    field(:status, :string)
    field(:active, :boolean)
  end
end
