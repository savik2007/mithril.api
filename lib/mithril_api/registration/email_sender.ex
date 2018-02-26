defmodule Mithril.Registration.EmailSender do
  use HTTPoison.Base
  use Confex, otp_app: :mithril_api
  #  alias Mithril.ResponseDecoder

  @behaviour Mithril.Registration.EmailBehaviour

  def process_url(url), do: config()[:endpoint] <> url

  def process_request_options(options), do: Keyword.merge(config()[:hackney_options], options)

  def send(email, verification_code, headers \\ []) do
    # write code
  end
end
