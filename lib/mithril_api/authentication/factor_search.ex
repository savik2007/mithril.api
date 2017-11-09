defmodule Mithril.Authentication.FactorSearch do
  @moduledoc false

  use Ecto.Schema

  @primary_key false
  schema "factor_search" do
    field :type, :string
    field :is_active, :boolean
  end
end
