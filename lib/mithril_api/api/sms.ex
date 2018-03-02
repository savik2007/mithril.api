defmodule Mithril.API.SMS do
  use HTTPoison.Base
  use Confex, otp_app: :mithril_api
  use Mithril.API.Helpers.MicroserviceBase

  @behaviour Mithril.API.SMSBehaviour

  def send(phone_number, body, type, headers \\ []) do
    post!("/sms/send", Poison.encode!(%{phone_number: phone_number, body: body, type: type}), headers)
  end
end
