defmodule Mithril.Web.OTPController do
  use Mithril.Web, :controller

  alias Scrivener.Page
  alias Mithril.Authentication
  alias Mithril.Guardian.Plug

  action_fallback(Mithril.Web.FallbackController)

  def index(conn, params) do
    with %Page{} = paging <- Authentication.list_otps(params) do
      render(conn, "index.json", otps: paging.entries, paging: paging)
    end
  end

  def send_otp(conn, params) do
    with jwt <- Plug.current_token(conn),
         :ok <- Authentication.send_otp(params, jwt) do
      render(conn, "send_otp.json", message: "OTP sent")
    end
  end
end
