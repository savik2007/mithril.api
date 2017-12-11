defmodule Mithril.Error do
  @moduledoc false

  @doc false
  def access_denied(msg),
      do: {:error, {:access_denied, msg}}

  def user_blocked(msg),
      do: {:error, {:access_denied, %{type: "user_blocked", message: msg}}}

  def token_expired,
      do: {:error, {:access_denied, %{type: "token_expired", message: "Token expired"}}}

  def token_invalid,
      do: {:error, {:access_denied, %{type: "token_invalid", message: "Invalid token."}}}

  def token_invalid_type,
      do: {:error, {:access_denied, %{type: "token_invalid_type", message: "Invalid token type."}}}

  def otp_invalid,
      do: {:error, {:access_denied, %{type: "otp_invalid", message: "Invalid OTP code."}}}

  def otp_expired,
      do: {:error, {:access_denied, %{type: "otp_expired", message: "OTP expired."}}}

  def otp_timeout,
      do: {:error, {:too_many_requests, %{type: "otp_timeout", message: "Sending OTP timeout. Try later."}}}

  def otp_reached_max_attempts,
      do: {:error, {:access_denied, %{type: "otp_reached_max_attempts", message: "Reached max OTP verify attempts"}}}

  def invalid_user(msg),
      do: {:error, {:access_denied, %{type: "invalid_user", message: msg}}}

  def invalid_client(msg),
      do: {:error, {:access_denied, %{type: "invalid_client", message: msg}}}

  def invalid_grant(msg),
      do: {:error, {:access_denied, %{type: "invalid_grant", message: msg}}}

  def invalid_scope(scopes), do:
    {:error, {:access_denied, "Allowed scopes for the token are #{Enum.join(scopes, ", ")}."}}

  def unauthorized_client(msg),
      do: {:error, {:access_denied, %{type: "unauthorized_client", message: msg}}}

  def invalid_request(msg),
      do: {:error, {:unprocessable_entity, msg}}

  def unsupported_grant_type, do:
    {:error, {:unprocessable_entity, "The authorization grant type is not supported by the authorization server."}}
end
