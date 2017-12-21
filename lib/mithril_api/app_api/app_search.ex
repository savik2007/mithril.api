defmodule Mithril.AppAPI.AppSearch do
  @moduledoc false

  use Ecto.Schema

  schema "app_search" do
    field :user_id, Ecto.UUID
    field :client_id, Ecto.UUID
  end
end
