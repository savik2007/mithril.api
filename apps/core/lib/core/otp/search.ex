defmodule Core.OTP.Search do
  @moduledoc false

  use Ecto.Schema

  alias Core.Ecto.StringLike

  @primary_key false
  embedded_schema do
    field(:key, StringLike)
    field(:status, :string)
    field(:active, :boolean)
  end
end
