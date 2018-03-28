defmodule Mithril.Guardian do
  @moduledoc false

  use Guardian, otp_app: :mithril_api

  def subject_for_token(:email, %{"email" => email}) do
    {:ok, email}
  end

  def subject_for_token(:nonce, %{"nonce" => nonce}) do
    {:ok, nonce}
  end
end
