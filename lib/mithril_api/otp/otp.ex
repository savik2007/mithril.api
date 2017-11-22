defmodule Mithril.OTP do
  @moduledoc """
  The boundary for the OTP system.
  """

  import Ecto.{Query, Changeset}, warn: false

  alias Mithril.Repo
  alias Mithril.OTP.Schema, as: OTPSchema

  @status_new "NEW"
  @status_verified "VERIFIED"
  @status_unverified "UNVERIFIED"
  @status_canceled "CANCELED"
  @status_expired "EXPIRED"
  @status_completed "COMPLETED"

  @required_fields ~w(key code code_expired_at status)a
  @optional_fields ~w(attempts_count)a

  @otp_config Confex.get_env(:mithril_api, :"2fa")
  @otp_ttl @otp_config[:otp_ttl]
  @otp_length @otp_config[:otp_length]
  @otp_max_attempts @otp_config[:otp_max_attempts]

  @doc """
  Returns the list of otps.

  ## Examples

      iex> list_otps()
      [%Mithril.OTP.Schema{}]

  """
  @spec list_otps :: [OTPSchema.t] | []
  def list_otps do
    Repo.all(OTPSchema)
  end

  @doc """
  Gets a single OTP.

  Raises `Ecto.NoResultsError` if the OTPSchema does not exist.

  ## Examples

      iex> get_otp!(123)
      %Mithril.OTP.Schema{}

      iex> get_otp!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_otp(id :: String.t) :: OTPSchema.t | nil | no_return
  def get_otp(id), do: Repo.get(OTPSchema, id)
  def get_otp!(id), do: Repo.get!(OTPSchema, id)

  @doc """
  Gets a single OTP.

  Raises `Ecto.NoResultsError` if the OTPSchema does not exist.

  ## Examples

      iex> get_otp_by!(123)
      %Mithril.OTP.Schema
  """
  @spec get_otp_by!(params :: Keyword.t) :: OTPSchema.t | []
  def get_otp_by!(params) do
    OTPSchema
    |> order_by(desc: :inserted_at)
    |> limit(1)
    |> Repo.get_by!(params)
  end

  @doc """
  Creates a OTP.

  ## Examples

      iex> create_otp(%{field: value})
      {:ok, %Mithril.OTP.Schema{}}

      iex> create_otp(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_otp(attrs :: %{}) :: {:ok, OTPSchema.t} | {:error, Ecto.Changeset.t}
  def create_otp(attrs \\ %{}) do
    %OTPSchema{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @spec initialize_otp(key :: String.t) :: {:ok, OTPSchema.t} | {:error, Ecto.Changeset.t}
  def initialize_otp(key) do
    deactivate_otps(key)
    attrs = initialize_attrs(key)

    %OTPSchema{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @spec initialize_attrs(key :: String.t) :: %{}
  defp initialize_attrs(key) do
    %{
      "key" => key,
      "code" => generate_otp_code(@otp_length),
      "status" => @status_new,
      "code_expired_at" => get_code_expiration_time(),
    }
  end

  @spec verify(otp :: %{key: String.t}, code :: Integer.t) :: tuple()
  def verify(key, code) do
    otp = get_otp_by!([key: key, status: @status_new])

    with :ok <- verify_expiration_time(otp),
         :ok <- verify_max_attemps(otp),
         :ok <- verify_code(otp, code)

    do
      otp_completed(otp)

    else
      error -> otp_does_not_completed(otp, error)
    end
  end

  @spec verify_expiration_time(otp :: OTPSchema.t) :: atom()
  defp verify_expiration_time(%OTPSchema{code_expired_at: code_expired_at}) do
    if Timex.before?(Timex.now, code_expired_at),
       do: :ok,
       else: :expired
  end

  @spec verify_max_attemps(otp :: OTPSchema.t) :: atom()
  defp verify_max_attemps(%OTPSchema{attempts_count: attempts_count}) do
    if attempts_count < @otp_max_attempts,
       do: :ok,
       else: :reached_max_attempts
  end

  @spec verify_code(otp :: OTPSchema.t, code :: Integer.t) :: atom()
  defp verify_code(%OTPSchema{} = otp, code) do
    if otp.code == code,
       do: :ok,
       else: :invalid_code
  end

  @spec otp_completed(otp :: OTPSchema.t) :: tuple()
  defp otp_completed(%OTPSchema{} = otp) do
    otp
    |> update_otp(%{status: @status_verified, active: false, attempts_count: otp.attempts_count + 1})
    |> Tuple.append(:verified)
  end

  @spec otp_does_not_completed(otp :: OTPSchema.t, error :: atom) :: tuple()
  defp otp_does_not_completed(%OTPSchema{} = otp, error) do
    attrs = case error do
      :invalid_code -> %{attempts_count: otp.attempts_count + 1}
      _ -> %{status: @status_unverified, active: false}
    end

    otp
    |> update_otp(attrs)
    |> Tuple.append(error)
  end

  @doc """
  Updates a OTP.

  ## Examples

      iex> update_otp(OTP, %{field: new_value})
      {:ok, %Mithril.OTP.Schema{}}

      iex> update_otp(OTP, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_otp(otp :: OTPSchema.t, %{}) :: {:ok, OTPSchema.t} | {:error, Ecto.Changeset.t}
  def update_otp(%OTPSchema{} = otp, attrs) do
    otp
    |> changeset(attrs)
    |> Repo.update()
  end

  @spec changeset(otp :: OTPSchema.t, %{}) :: Ecto.Changeset.t
  defp changeset(%OTPSchema{} = otp, attrs) do
    otp
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, [@status_new, @status_verified, @status_unverified, @status_completed])
  end

  @spec generate_otp_code(number_length :: pos_integer()) :: pos_integer()
  defp generate_otp_code(number_length) do
    1..number_length
    |> Enum.map(fn _ -> :rand.uniform(9) end)
    |> Enum.join()
    |> String.to_integer()
  end

  @spec get_code_expiration_time :: String.t
  defp get_code_expiration_time, do:
    DateTime.to_iso8601(Timex.shift(Timex.now, seconds: @otp_ttl))

  @spec deactivate_otps(key :: String.t) :: {integer, nil | [term]} | no_return
  defp deactivate_otps(key) do
    data = [status: @status_canceled]

    OTPSchema
    |> where(key: ^key)
    |> where(active: true)
    |> Repo.update_all(set: data)
  end

  @spec cancel_expired_otps() :: {integer, nil | [term]} | no_return
  def cancel_expired_otps do
    data = [status: @status_expired, active: false]

    OTPSchema
    |> where(active: true)
    |> where([o], o.code_expired_at < ^Timex.now)
    |> Repo.update_all(set: data)
  end
end
