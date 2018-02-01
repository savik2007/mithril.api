defmodule Mithril.ClientAPI.ClientSearch do
  @moduledoc false

  use Ecto.Schema

  schema "client_search" do
    field(:name, :string)
    field(:user_id, Ecto.UUID)
    field(:is_blocked, :boolean)
  end
end
