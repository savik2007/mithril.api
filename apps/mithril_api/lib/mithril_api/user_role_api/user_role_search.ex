defmodule Mithril.UserRoleAPI.UserRoleSearch do
  @moduledoc false

  use Ecto.Schema

  @primary_key false
  schema "user_role_search" do
    field(:role_id, Ecto.UUID)
    # ToDo: remember, that field user_ids is hardcoded in UserRoleAPI.query_where
    field(:user_ids, Ecto.CommaParamsUUID)
    field(:user_id, Ecto.UUID)
    field(:client_id, Ecto.UUID)
  end
end
