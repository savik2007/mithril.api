defmodule Core.AppAPI.AppSearch do
  @moduledoc false

  use Ecto.Schema

  @user_id_prefix "user-"
  @client_id_prefix "client-"
  @client_name_prefix "client_name-"

  schema "app_search" do
    field(:client_ids, :string)
    field(:client_names, :string)
    field(:user_id, :string)
  end

  def prefix("user_id"), do: @user_id_prefix
  def prefix("client_ids"), do: @client_id_prefix
  def prefix("client_names"), do: @client_name_prefix
end
