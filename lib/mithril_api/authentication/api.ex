defmodule Mithril.Authentication do
  @doc false

  use Mithril.Search

  import Ecto.{Query, Changeset, DateTime}, warn: false

  alias Mithril.Repo
  alias Mithril.Authentication.Factor
  alias Mithril.Authentication.FactorSearch

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

  def get_factor!(id),
      do: Factor
          |> Repo.get!(id)
          |> Repo.preload(:user)

  def get_factor_by(params),
      do: Factor
          |> Repo.get_by(params)
          |> Repo.preload(:user)

  def get_factor_by!(params),
      do: Factor
          |> Repo.get_by!(params)
          |> Repo.preload(:user)

  def list_factors(params \\ %{}) do
    %FactorSearch{}
    |> changeset(params)
    |> search(params, Factor)
  end

  def create_factor(attrs) do
    %Factor{}
    |> changeset(attrs)
    |> Repo.insert()
    |> preload_references()
  end

  def update_factor(%Factor{} = factor, attrs) do
    factor
    |> changeset(attrs)
    |> Repo.update()
    |> preload_references()
  end

  def changeset(%FactorSearch{} = factor, attrs) do
    cast(factor, attrs, FactorSearch.__schema__(:fields))
  end

  def changeset(%Factor{} = client, attrs) do
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

  defp preload_references({:ok, factor}),
       do: {:ok, preload_references(factor)}

  defp preload_references(%Factor{} = factor),
       do: Repo.preload(factor, :user)

  defp preload_references(err),
       do: err
end
