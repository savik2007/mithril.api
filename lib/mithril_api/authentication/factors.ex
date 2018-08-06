defmodule Mithril.Authentication.Factors do
  @doc false

  import Mithril.Search

  import Ecto.{Query, Changeset}, warn: false
  import Mithril.Authentication, only: [generate_otp_key: 2]

  alias Mithril.Authentication.Factor
  alias Mithril.Authentication.FactorSearch
  alias Mithril.OTP
  alias Mithril.Repo

  @type_sms "SMS"

  @fields_required ~w(type user_id)a
  @fields_optional ~w(otp email factor is_active)a

  def type(:sms), do: @type_sms

  def get_factor!(id) do
    Factor
    |> Repo.get!(id)
    |> Repo.preload(:user)
  end

  def get_factor_by(params) do
    Factor
    |> Repo.get_by(params)
    |> Repo.preload(:user)
  end

  def get_factor_by!(params) do
    Factor
    |> Repo.get_by!(params)
    |> Repo.preload(:user)
  end

  def list_factors(params \\ %{}) do
    %FactorSearch{}
    |> changeset(params)
    |> search(params, Factor)
  end

  def create_factor(attrs) do
    attrs
    |> create_factor_changeset()
    |> Repo.insert()
    |> preload_references()
  end

  def update_factor(%Factor{} = factor, attrs) do
    factor
    |> changeset(attrs)
    |> Repo.update()
    |> preload_references()
  end

  def update_factor(%Factor{} = factor, attrs, :with_otp_validation) do
    factor
    |> changeset(attrs)
    |> validate_factor_and_otp()
    |> Repo.update()
    |> preload_references()
  end

  def create_factor_changeset(attrs) do
    changeset(%Factor{}, attrs)
  end

  def changeset(%FactorSearch{} = schema, attrs) do
    cast(schema, attrs, FactorSearch.__schema__(:fields))
  end

  def changeset(%Factor{} = schema, attrs) do
    schema
    |> cast(attrs, @fields_required ++ @fields_optional)
    |> validate_required(@fields_required)
    |> validate_inclusion(:type, [@type_sms])
    |> validate_factor_format()
    |> unique_constraint(:user_id, name: "authentication_factors_user_id_type_index")
    |> assoc_constraint(:user)
  end

  def validate_factor_and_otp(changeset) do
    validate_change(changeset, :factor, fn :factor, factor ->
      otp = fetch_change(changeset, :otp)
      email = fetch_change(changeset, :email)
      validate_otp(otp, email, factor)
    end)
  end

  defp validate_otp(:error, _email, _factor), do: [otp: {"can't be blank", [validation: "required"]}]
  defp validate_otp(_otp, :error, _factor), do: [email: {"can't be blank", [validation: "required"]}]

  defp validate_otp({_, otp}, {_, email}, factor) do
    email
    |> generate_otp_key(factor)
    |> OTP.verify(otp)
    |> case do
      {:error, _} -> [otp: {"invalid code", [validation: "invalid"]}]
      {:ok, _, :invalid_code} -> [otp: {"invalid code", [validation: "invalid"]}]
      {:ok, _, :expired} -> [otp: {"expired", [validation: "invalid"]}]
      {:ok, _, :verified} -> []
    end
  end

  def validate_factor_format(changeset) do
    validate_change(changeset, :factor, fn :factor, factor ->
      changeset
      |> fetch_field(:type)
      |> case do
        :error -> :error
        {_, value} -> value
      end
      |> validate_factor_format(factor)
    end)
  end

  defp validate_factor_format(@type_sms, nil), do: []

  defp validate_factor_format(@type_sms, value) do
    case value =~ ~r/^\+380[0-9]{9}$/ do
      true -> []
      false -> [factor: {"invalid phone", [validation: "format"]}]
    end
  end

  defp validate_factor_format(_, _) do
    []
  end

  defp preload_references({:ok, factor}), do: {:ok, preload_references(factor)}
  defp preload_references(%Factor{} = factor), do: Repo.preload(factor, :user)
  defp preload_references(err), do: err
end
