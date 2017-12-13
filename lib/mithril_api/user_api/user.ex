defmodule Mithril.UserAPI.User do
  @moduledoc false

  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "users" do
    field :email, :string
    field :password, :string
    field :password_set_at, :naive_datetime
    field :current_password, :string, virtual: true
    field :settings, :map, default: %{}
    field :is_blocked, :boolean, default: false
    field :block_reason, :string

    embeds_one :priv_settings, PrivSettings, primary_key: false, on_replace: :update do
      field :login_error_counter, :integer, default: 0
      field :otp_send_counter, :integer, default: 0
      field :otp_error_counter, :integer, default: 0
      field :last_send_otp_timestamp, :integer, default: 0
    end

    has_many :user_roles, Mithril.UserRoleAPI.UserRole
    has_many :roles, through: [:user_roles, :role]

    timestamps()
  end
end
