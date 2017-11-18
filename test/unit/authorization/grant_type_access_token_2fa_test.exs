defmodule Mithril.Authorization.GrantType.AccessToken2FATest do
  use Mithril.DataCase, async: false

  alias Mithril.Authorization.GrantType.AccessToken2FA

  @direct Mithril.ClientAPI.access_type(:direct)

  setup do
    user = insert(:user, password: Comeonin.Bcrypt.hashpwsalt("super$ecre7"))
    client_type = insert(:client_type, scope: "app:authorize legal_entity:read legal_entity:write")
    client = insert(
      :client,
      user_id: user.id,
      redirect_uri: "http://localhost",
      client_type_id: client_type.id,
      settings: %{"allowed_grant_types" => ["password"]},
      priv_settings: %{"access_type" => @direct}
    )
    insert(:authentication_factor, user_id: user.id)
    role = insert(:role, scope: "legal_entity:read legal_entity:write")
    insert(:user_role, user_id: user.id, role_id: role.id, client_id: client.id)
    token = insert(:token, user_id: user.id, name: "2fa_access_token")

    {:ok, %{token: token}}
  end

  test "invalid OTP type", %{token: token} do
    data = %{
      "token_value" => token.value,
      "grant_type" => "authorize_2fa_access_token",
      "otp" => "invalid type"
    }
    assert %Ecto.Changeset{valid?: false} = AccessToken2FA.authorize(data)
  end
end
