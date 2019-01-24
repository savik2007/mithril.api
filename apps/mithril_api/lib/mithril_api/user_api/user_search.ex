defmodule Mithril.UserAPI.UserSearch do
  @moduledoc false

  use Ecto.Schema

  @primary_key false
  schema "user_search" do
    field(:id, Ecto.UUID)
    # ToDo: remember, that field user_ids is hardcoded in UserRoleAPI.query_where
    field(:ids, Ecto.CommaParamsUUID)
    field(:email, :string)
    field(:tax_id, :string)
    field(:is_blocked, :boolean)
  end
end
