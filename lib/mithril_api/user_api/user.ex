defmodule Mithril.UserAPI.User do
  @moduledoc false

  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "users" do
    field(:email, :string)
    field(:password, :string)
    field(:password_set_at, :naive_datetime)
    field(:current_password, :string, virtual: true)
    field(:settings, :map, default: %{})
    field(:is_blocked, :boolean, default: false)
    field(:block_reason, :string)

    embeds_one :priv_settings, PrivSettings, primary_key: false, on_replace: :update do
      embeds_many(:login_hstr, Mithril.UserAPI.User.LoginHstr, on_replace: :delete)
      field(:otp_error_counter, :integer, default: 0)
    end

    has_many(:user_roles, Mithril.UserRoleAPI.UserRole)
    has_many(:roles, through: [:user_roles, :role])

    timestamps()
  end
end

defmodule Mithril.UserAPI.User.LoginHstr do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:type, :string)
    field(:is_success, :boolean, default: false)
    field(:time, :naive_datetime)
  end

  @fields_required ~w(type time)a
  @fields_optional ~w(is_success)a

  def changeset(%__MODULE__{} = login_hstr, attrs) do
    login_hstr
    |> cast(attrs, @fields_required ++ @fields_optional)
    |> validate_required(@fields_required)
  end
end
