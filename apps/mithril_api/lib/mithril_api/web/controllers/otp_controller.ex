defmodule Mithril.Web.OTPController do
  use Mithril.Web, :controller

  alias Mithril.Authentication
  alias Mithril.Guardian.Plug
  alias Mithril.OTP
  alias Scrivener.Page

  action_fallback(Mithril.Web.FallbackController)

  def index(conn, params) do
    with %Page{} = paging <- OTP.list_otps(params) do
      render(conn, "index.json", otps: paging.entries, paging: paging)
    end
  end

  def send_otp(conn, params) do
    with jwt <- Plug.current_token(conn),
         {:ok, code} <- Authentication.send_otp(params, jwt) do
      conn
      |> assign_code(code)
      |> render("send_otp.json", message: "OTP sent")
    end
  end

  def verifications(conn, params) do
    with jwt <- Plug.current_token(conn),
         :ok <- Authentication.verifications(params, jwt, conn.req_headers) do
      render(conn, "send_otp.json", message: "OTP sent")
    end
  end

  defp assign_code(conn, code) do
    case Confex.fetch_env!(:mithril_api, :sensitive_data_in_response) do
      true -> assign(conn, :urgent, %{code: code})
      false -> conn
    end
  end
end
