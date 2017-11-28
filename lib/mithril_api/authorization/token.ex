defmodule Mithril.Authorization.Token do
  @moduledoc false

  # Functions in this module create new access_tokens,
  # based on grant_type the request came with

  alias Mithril.Error
  alias Mithril.Authorization.GrantType.Password
  alias Mithril.Authorization.GrantType.AuthorizationCode
  alias Mithril.Authorization.GrantType.RefreshToken
  alias Mithril.Authorization.GrantType.AccessToken2FA

  # TODO: rename grant_type to response_type
  def authorize(%{"grant_type" => "password"} = params) do
    Password.authorize(params)
  end

  def authorize(%{"grant_type" => "authorize_2fa_access_token"} = params) do
    AccessToken2FA.authorize(params)
  end

  def authorize(%{"grant_type" => "refresh_2fa_access_token"} = params) do
    AccessToken2FA.refresh(params)
  end

  def authorize(%{"grant_type" => "authorization_code"} = params) do
    AuthorizationCode.authorize(params)
  end

  def authorize(%{"grant_type" => "refresh_token"} = params) do
    RefreshToken.authorize(params)
  end

  def authorize(_) do
    Error.invalid_request("Request must include grant_type.")
  end
end
