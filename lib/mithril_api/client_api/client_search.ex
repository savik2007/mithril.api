defmodule Mithril.ClientAPI.ClientSearch do
  @moduledoc false

  use Ecto.Schema
  alias Mithril.Ecto.StringLike

  embedded_schema do
    field(:name, StringLike)
    field(:user_id, Ecto.UUID)
    field(:is_blocked, :boolean)
  end
end
