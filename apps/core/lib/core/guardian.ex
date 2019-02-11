defmodule Core.Guardian do
  @moduledoc false

  use Guardian, otp_app: :core

  @aud_login "mithril-login"
  @aud_registration "cabinet-registration"

  def get_aud(:login), do: @aud_login
  def get_aud(:registration), do: @aud_registration

  def subject_for_token(:email, %{"email" => email}), do: {:ok, email}
  def subject_for_token(:nonce, %{"nonce" => nonce}), do: {:ok, nonce}

  def build_claims(claims, :nonce, _opts), do: {:ok, Map.put(claims, "aud", @aud_login)}
  def build_claims(claims, :email, _opts), do: {:ok, Map.put(claims, "aud", @aud_registration)}
  def build_claims(claims, _resource, _opts), do: {:ok, claims}
end
