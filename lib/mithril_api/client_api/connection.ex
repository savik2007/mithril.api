defmodule Mithril.ClientAPI.Connection do
  use Ecto.Schema
  import Ecto.Changeset
  alias Mithril.ClientAPI.Client

  @required ~w(redirect_uri client_id consumer_id)a

  @foreign_key_type :binary_id
  @primary_key {:id, :binary_id, autogenerate: true}

  schema "connections" do
    field(:secret, :string)
    field(:redirect_uri, :string)

    belongs_to(:client, Client)
    belongs_to(:consumer, Client)

    timestamps()
  end

  @doc false
  def changeset(connection, attrs) do
    connection
    |> cast(attrs, @required)
    |> put_secret()
    |> validate_required(@required)
    |> validate_format(:redirect_uri, ~r{^https?://.+})
    |> unique_constraint(:secret)
  end

  defp put_secret(changeset) do
    case fetch_field(changeset, :secret) do
      {:data, nil} -> put_change(changeset, :secret, SecureRandom.urlsafe_base64())
      _ -> changeset
    end
  end
end
