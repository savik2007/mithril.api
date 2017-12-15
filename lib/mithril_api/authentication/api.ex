defmodule Mithril.Authentication do
  @doc false

  use Mithril.Search

  import Ecto.{Query, Changeset, DateTime}, warn: false

  alias Mithril.OTP
  alias Mithril.OTP.SMS
  alias Mithril.OTP.Schema, as: OTPSchema
  alias Mithril.Repo
  alias Mithril.UserAPI
  alias Mithril.UserAPI.User
  alias Mithril.TokenAPI.Token
  alias Mithril.Authentication.{Factor, FactorSearch, OTPSearch}

  require Logger

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

  def list_otps(params) do
    %OTPSearch{}
    |> changeset(params)
    |> search(params, OTPSchema)
  end

  def send_otp(%User{} = user, %Factor{factor: value} = factor, %Token{} = token)
      when is_binary(value) and byte_size(value) > 0 do

    with true <- can_send_otp?(user),
         otp <- token
                |> generate_key(value)
                |> OTP.initialize_otp(),
         :ok <- maybe_send_otp(otp, factor)
      do
        :ok
    end
  end
  def send_otp(_user, %Factor{}, _token) do
    {:error, :factor_not_set}
  end

  defp maybe_send_otp(otp, factor) do
    case Confex.get_env(:mithril_api, :"2fa")[:sms_enabled?] do
      true -> send_otp_by_factor(otp, factor)
      false -> :ok
    end
  end

  defp send_otp_by_factor({:ok, %OTPSchema{code: code}}, %Factor{factor: factor, type: @type_sms}) do
    case SMS.send(factor, generate_message(code), "2FA") do
      {:ok, _} ->
        :ok
      err ->
        Logger.error("Cannot send 2FA SMS with error: #{inspect(err)}")
        {:error, :sms_not_sent}
    end
  end
  defp send_otp_by_factor(err, _) do
    Logger.error("Cannot initialize_otp with error: #{inspect(err)}")
    {:error, :sms_not_sent}
  end

  defp can_send_otp?(%User{priv_settings: priv_settings} = user) do
    case {otp_timeout?(priv_settings), otp_reached_max_send_counter?(priv_settings)} do
      # OTP timed out and reached max send attempts
      {true, true} ->
        {:error, :otp_timeout}

      # OTP timed out but NOT reached max send attempts
      {true, false} ->
        UserAPI.merge_user_priv_settings(user, %{
          last_send_otp_timestamp: :os.system_time(:seconds),
          otp_send_counter: Map.get(priv_settings, :otp_send_counter, 0) + 1
        })
        true

      # OTP NOT timed out but reached max send attempts
      {false, true} ->
        UserAPI.merge_user_priv_settings(user, %{
          last_send_otp_timestamp: :os.system_time(:seconds),
          otp_send_counter: 1
        })
        true

      # OTP NOT timed out and NOT reached max send attempts
      {false, false} ->
        UserAPI.merge_user_priv_settings(user, %{
          last_send_otp_timestamp: :os.system_time(:seconds),
          otp_send_counter: Map.get(priv_settings, :otp_send_counter, 0) + 1
        })
        true
    end
  end

  defp otp_timeout?(priv_settings) do
    timeout = Confex.get_env(:mithril_api, :"2fa")[:otp_send_timeout]
    last_send_otp = Map.get(priv_settings, :last_send_otp_timestamp, 0)
    timeout + last_send_otp > :os.system_time(:seconds)
  end
  defp otp_reached_max_send_counter?(priv_settings) do
    Map.get(priv_settings, :otp_send_counter, 0) + 1 > Confex.get_env(:mithril_api, :"2fa")[:otp_send_counter_max]
  end

  def verify_otp(%Factor{factor: value}, %Token{} = token, otp) when is_binary(value) do
    verify_otp(value, token, otp)
  end
  def verify_otp(value, %Token{} = token, otp) when is_binary(value) and byte_size(value) > 1 do
    token
    |> generate_key(value)
    |> OTP.verify(otp)
  end
  def verify_otp(_value, _token, _otp) do
    {:error, :factor_not_set}
  end

  def generate_key(%Token{} = token, value) do
    token.id <> "===" <> value
  end

  def generate_message(code) when is_integer(code) do
    code
    |> Integer.to_string()
    |> generate_message()
  end
  def generate_message(code) do
    code_mask = "<otp.code>"
    sms_template = Confex.get_env(:mithril_api, :"2fa")[:otp_sms_template]

    case valid_sms_template?(sms_template, code_mask) do
      true -> String.replace(sms_template, code_mask, code)
      false -> code
    end
  end

  defp valid_sms_template?(sms_template, code_mask) when is_binary(sms_template) do
    String.contains?(sms_template, code_mask)
  end
  defp valid_sms_template?(_, _) do
    false
  end

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
    attrs
    |> create_changeset()
    |> Repo.insert()
    |> preload_references()
  end

  def update_factor(%Factor{} = factor, attrs) do
    factor
    |> changeset(attrs)
    |> Repo.update()
    |> preload_references()
  end

  def create_changeset(attrs) do
    changeset(%Factor{}, attrs, @fields_required)
  end

  def changeset(%FactorSearch{} = factor, attrs) do
    cast(factor, attrs, FactorSearch.__schema__(:fields))
  end

  def changeset(%OTPSearch{} = factor, attrs) do
    cast(factor, attrs, OTPSearch.__schema__(:fields))
  end

  def changeset(%Factor{} = client, attrs, cast_fields \\ @fields_required ++ @fields_optional) do
    client
    |> cast(attrs, cast_fields)
    |> validate_required(@fields_required)
    |> validate_inclusion(:type, [@type_sms])
    |> validate_factor_format()
    |> unique_constraint(:user_id, name: "authentication_factors_user_id_type_index")
    |> assoc_constraint(:user)
  end

  def validate_factor_format(changeset) do
    validate_change changeset, :factor, fn :factor, factor ->
      changeset
      |> fetch_field(:type)
      |> case do
           :error -> :error
           {_, value} -> value
         end
      |> validate_factor_format(factor)
    end
  end

  defp validate_factor_format(@type_sms, nil) do
    []
  end
  defp validate_factor_format(@type_sms, value) do
    case value =~ ~r/^\+380[0-9]{9}$/ do
      true -> []
      false -> [factor: "invalid phone"]
    end
  end
  defp validate_factor_format(_, _) do
    []
  end

  defp preload_references({:ok, factor}),
       do: {:ok, preload_references(factor)}

  defp preload_references(%Factor{} = factor),
       do: Repo.preload(factor, :user)

  defp preload_references(err),
       do: err
end
