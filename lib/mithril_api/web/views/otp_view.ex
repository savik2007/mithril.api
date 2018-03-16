defmodule Mithril.Web.OTPView do
  use Mithril.Web, :view

  @fields ~w(id key code code_expired_at status active attempts_count inserted_at updated_at)a

  def render("index.json", %{otps: otps}) do
    render_many(otps, __MODULE__, "otp.json")
  end

  def render("show.json", %{otp: otp}) do
    render_one(otp, __MODULE__, "otp.json")
  end

  def render("otp.json", %{otp: otp}) do
    Map.take(otp, @fields)
  end

  def render("send_otp.json", %{message: message}) do
    %{result: message}
  end
end
