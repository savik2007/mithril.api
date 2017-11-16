defmodule Mithril.OTP.API do
  @moduledoc false

  alias Mithril.OTP
  alias Mithril.OTP.SMS
  alias Mithril.OTP.Schema, as: OTPSchema
  alias Mithril.TokenAPI.Token
  alias Mithril.Authentication
  alias Mithril.Authentication.Factor

  require Logger

  @type_sms Authentication.type(:sms)

  def send_otp(%Factor{factor: value} = factor, %Token{} = token) when is_binary(value) do
    token
    |> generate_key(value)
    |> OTP.initialize_otp()
    |> send_otp_by_factor(factor)
  end
  def send_otp(%Factor{factor: value} = factor, token) when is_nil(value) do
    {:error, :factor_not_set}
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

  def verify_otp do

  end

  defp generate_key(%Token{} = token, value) do
    token.id <> "===" <> value
  end

  defp generate_message(code) do
    # ToDo: write code
    code
  end
end
