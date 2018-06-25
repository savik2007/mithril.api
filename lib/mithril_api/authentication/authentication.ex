defmodule Mithril.Authentication do
  @doc false

  import Ecto.{Query, Changeset, DateTime}, warn: false

  alias Mithril.{OTP, Error, Guardian, ClientAPI}
  alias Mithril.OTP.Schema, as: OTPSchema
  alias Mithril.UserAPI.User
  alias Mithril.TokenAPI.Token
  alias Mithril.Authentication.{Factor, Factors, OTPSend}
  alias Mithril.Authorization.LoginHistory

  require Logger

  @type_sms "SMS"
  @sms_api Application.get_env(:mithril_api, :api_resolvers)[:sms]

  def type(:sms), do: @type_sms

  def send_otp(%User{} = user, %Factor{factor: value} = factor, %Token{} = token)
      when is_binary(value) and byte_size(value) > 0 do
    with :ok <- LoginHistory.check_sent_otps(user),
         otp <-
           token
           |> generate_otp_key(value)
           |> OTP.initialize_otp(),
         _ <- LoginHistory.add_login(user, LoginHistory.type(:otp), true),
         :ok <- maybe_send_otp(otp, factor) do
      :ok
    end
  end

  def send_otp(_user, %Factor{}, _token) do
    {:error, :factor_not_set}
  end

  def send_otp(params, jwt) do
    with {:ok, %{"email" => email}} <- Guardian.decode_and_verify(jwt),
         %Ecto.Changeset{valid?: true} <- changeset(%OTPSend{}, params),
         factor <- %Factor{factor: params["factor"], type: params["type"]},
         otp_key <- generate_otp_key(email, factor.factor),
         :ok <- check_sent_otps(otp_key),
         {:ok, %OTPSchema{code: code}} = otp <- OTP.initialize_otp(otp_key),
         :ok <- maybe_send_otp(otp, factor) do
      {:ok, code}
    else
      {:error, :sms_not_sent} -> {:error, {:service_unavailable, "SMS not sent. Try later"}}
      err -> err
    end
  end

  def verifications(params, jwt, headers) do
    with {:ok, %{"email" => _}} <- Guardian.decode_and_verify(jwt),
         %Ecto.Changeset{valid?: true} <- changeset(%OTPSend{}, params),
         factor <- %Factor{factor: params["factor"], type: params["type"]},
         :ok <- verifications_init(factor, headers) do
      :ok
    else
      {:error, :sms_not_sent} -> {:error, {:service_unavailable, "SMS not sent. Try later"}}
      err -> err
    end
  end

  defp changeset(%OTPSend{} = schema, attrs) do
    fields = OTPSend.__schema__(:fields)

    schema
    |> cast(attrs, fields)
    |> validate_required(fields)
    |> validate_inclusion(:type, [@type_sms])
    |> Factors.validate_factor_format()
  end

  defp check_sent_otps(otp_key) do
    conf = Confex.get_env(:mithril_api, :"2fa")
    timeout = conf[:otp_send_timeout]
    max_otps = conf[:otp_send_counter_max]
    do_check_sent_otps(otp_key, max_otps, timeout)
  end

  defp do_check_sent_otps(otp_key, max_otps, timeout) do
    inserted_at = NaiveDateTime.add(NaiveDateTime.utc_now(), -timeout * 60, :second)
    otps = OTP.list_otps_by_key_and_inserted_at(otp_key, inserted_at)

    case length(otps) >= max_otps do
      true -> Error.otp_timeout()
      false -> :ok
    end
  end

  defp maybe_send_otp(otp, factor) do
    case Confex.get_env(:mithril_api, :"2fa")[:sms_enabled?] do
      true -> send_otp_by_factor(otp, factor)
      false -> :ok
    end
  end

  defp send_otp_by_factor({:ok, %OTPSchema{code: code}}, %Factor{factor: factor, type: @type_sms}) do
    case @sms_api.send(factor, generate_otp_message(code), "2FA") do
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

  def verify_otp(%Factor{factor: value}, %Token{} = token, otp) when is_binary(value) do
    verify_otp(value, token, otp)
  end

  def verify_otp(value, %Token{} = token, otp) when is_binary(value) and byte_size(value) > 1 do
    token
    |> generate_otp_key(value)
    |> OTP.verify(otp)
  end

  def verify_otp(_value, _token, _otp) do
    {:error, :factor_not_set}
  end

  def generate_otp_key(%Token{id: id}, value), do: generate_otp_key(id, value)
  def generate_otp_key(prefix, value) when is_binary(prefix) and is_binary(value), do: prefix <> "===" <> value

  def generate_otp_message(code) when is_integer(code) do
    code
    |> Integer.to_string()
    |> generate_otp_message()
  end

  def generate_otp_message(code) do
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

  defp valid_sms_template?(_, _), do: false

  def generate_nonce_for_client(client_id) when is_binary(client_id) do
    ttl = {Confex.fetch_env!(:mithril_api, :ttl_login), :minutes}

    with %{is_blocked: false} <- ClientAPI.get_client!(client_id) do
      Guardian.encode_and_sign(:nonce, %{nonce: 123}, token_type: "access", ttl: ttl)
    else
      %{is_blocked: true} -> {:error, {:access_denied, "Client is blocked"}}
    end
  end

  defp verifications_init(factor, headers) do
    case Confex.get_env(:mithril_api, :"2fa")[:sms_enabled?] do
      true -> verifications_init_by_factor(factor, headers)
      false -> :ok
    end
  end

  defp verifications_init_by_factor(%Factor{factor: factor, type: @type_sms}, headers) do
    case @sms_api.verifications(factor, headers) do
      {:ok, _} ->
        :ok

      {:error, %{"error" => reason, "meta" => %{"code" => 429}}} ->
        {:error, {:too_many_requests, reason}}

      err ->
        Logger.error("Cannot send 2FA SMS with error: #{inspect(err)}")
        {:error, :sms_not_sent}
    end
  end
end
