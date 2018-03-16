defmodule Mithril.Web.OTPController do
  use Mithril.Web, :controller

  alias Mithril.Authentication
  alias Scrivener.Page

  action_fallback(Mithril.Web.FallbackController)

  def index(conn, params) do
    with %Page{} = paging <- Authentication.list_otps(params) do
      render(conn, "index.json", otps: paging.entries, paging: paging)
    end
  end

  def send_otp(conn, params) do

  end
end
