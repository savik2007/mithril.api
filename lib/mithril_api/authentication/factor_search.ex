defmodule Mithril.Authentication.FactorSearch do
  @moduledoc false

  use Ecto.Schema

  @primary_key false
  schema "factor_search" do
    field :type, :string
    field :user_id, Ecto.UUID
    field :is_active, :boolean
  end
end
