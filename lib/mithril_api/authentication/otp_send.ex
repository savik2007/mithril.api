defmodule Mithril.Authentication.OTPSend do
  @moduledoc false

  use Ecto.Schema

  @primary_key false
  schema "otp_send" do
    field(:type, :string)
    field(:factor, :string)
  end
end
