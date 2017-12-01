defmodule Mithril.Authentication.OTPSearch do
  @moduledoc false

  use Ecto.Schema

  alias Mithril.Ecto.StringLike

  @primary_key false
  schema "otp_search" do
    field :key, StringLike
    field :status, :string
    field :active, :boolean
  end
end
