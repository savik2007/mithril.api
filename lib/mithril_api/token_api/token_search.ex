defmodule Mithril.TokenAPI.TokenSearch do
  @moduledoc false

  use Ecto.Schema
  alias Mithril.Ecto.StringLike

  embedded_schema do
    field(:name, StringLike)
    field(:value, StringLike)
    field(:user_id, Ecto.UUID)
    field(:client_id, Ecto.UUID)
  end
end
