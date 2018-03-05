defmodule Mithril.API.Email do
  use HTTPoison.Base
  use Confex, otp_app: :mithril_api
  use Mithril.API.Helpers.MicroserviceBase

  @behaviour Mithril.API.EmailBehaviour

  def send(_email, _verification_code, _headers \\ []) do
    # write code
  end
end
