defmodule Core.API.SMS do
  @moduledoc false
  use HTTPoison.Base
  use Confex, otp_app: :core
  use Core.API.Helpers.MicroserviceBase

  @behaviour Core.API.SMSBehaviour

  def send(phone_number, body, type, headers \\ []) do
    post!(
      "/sms/send",
      Poison.encode!(%{phone_number: phone_number, body: body, type: type}),
      headers
    )
  end

  def verifications(phone_number, headers \\ []) do
    post!("/verifications", Poison.encode!(%{phone_number: phone_number}), headers)
  end
end
