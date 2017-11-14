defmodule Mithril.Authorization.GrantType.AccessToken2FATest do
  use Mithril.DataCase, async: true

  alias Mithril.Authorization.GrantType.AccessToken2FA

  test "authorize 2FA access token" do
    allowed_scope = "app:authorize legal_entity:read legal_entity:write"
    password = "somepa$$word"
    user = insert(:user, password: Comeonin.Bcrypt.hashpwsalt(password))
    client_type = insert(:client_type, scope: allowed_scope)
    insert(:client,
      user_id: user.id,
      client_type_id: client_type.id,
      settings: %{"allowed_grant_types" => ["password"]}
    )
    insert(:authentication_factor, user_id: user.id)
    %{value: value} = insert(:token, user_id: user.id, name: "2fa_access_token")

    {:ok, token} = AccessToken2FA.authorize(%{
      "otp" => "123",
      "token_value" => value,
    })

    assert token.name == "access_token"
  end
end
