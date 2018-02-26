defmodule Mithril.Web.RegistrationController do
  use Mithril.Web, :controller

  alias Mithril.Registration.API, as: Registration

  action_fallback(Mithril.Web.FallbackController)

  def send_email_verification(conn, params) do
    with :ok <- Registration.send_email_verification(params) do
      render(conn, "send_email_verification.json", %{})
    end
  end
end
