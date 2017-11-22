defmodule Mithril.UserAPI.UserSearch do
  @moduledoc false

  use Ecto.Schema

  @primary_key false
  schema "user_search" do
    field :id, Ecto.UUID
    field :ids, Ecto.CommaParamsUUID # ToDo: remember, that field user_ids is hardcoded in UserRoleAPI.query_where
    field :email, :string
    field :is_blocked, :boolean
  end
end
