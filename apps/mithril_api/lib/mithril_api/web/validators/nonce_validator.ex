defmodule Mithril.NonceValidator do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Ecto.UUID

  embedded_schema do
    field(:client_id, UUID)
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, ~w(client_id)a)
    |> validate_required(~w(client_id)a)
  end
end
