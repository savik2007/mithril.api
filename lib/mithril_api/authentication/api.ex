defmodule Mithril.Authentication do
  @doc false

  import Ecto.{Query, Changeset}, warn: false
  alias Mithril.Repo
  alias Mithril.Authentication.Factors, as: FactorSchema

  @fields_required ~w(
    type
    user_id
  )a

  @fields_optional ~w(
    factor
    is_active
  )a

  @type_sms "SMS"

  def type(:sms), do: @type_sms

  def get_authentication_factor(id), do: Repo.get(FactorSchema, id)
  def get_authentication_factor!(id), do: Repo.get!(FactorSchema, id)

  def create_factor(attrs) do
    %FactorSchema{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  def update_factor(%FactorSchema{} = factor, attrs) do
    factor
    |> changeset(attrs)
    |> Repo.update()
  end

  defp changeset(%FactorSchema{} = client, attrs) do
    client
    |> cast(attrs, @fields_required ++ @fields_optional)
    |> validate_required(@fields_required)
    |> validate_inclusion(:type, [@type_sms])
    |> validate_factor()
    |> unique_constraint(:user_id, name: "authentication_factors_user_id_type_index")
    |> assoc_constraint(:user)
  end

  defp validate_factor(changeset) do
    validate_change changeset, :factor, fn :factor, factor ->
      changeset
      |> fetch_field(:type)
      |> elem(1)
      |> validate_factor(factor)
    end
  end

  def validate_factor(@type_sms, nil) do
    []
  end
  def validate_factor(@type_sms, value) do
    case value =~ ~r/^\+380[0-9]{9}$/ do
      true -> []
      false -> [factor: "invalid phone"]
    end
  end
  def validate_factor(_, _) do
    []
  end
end
