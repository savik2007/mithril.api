defmodule Mithril.Authorization.GrantType.RefreshTokenTest do
  use Mithril.DataCase, async: true

  alias Mithril.Authorization.GrantType.RefreshToken, as: RefreshTokenGrantType

  test "creates refresh-granted access token" do
    client = Mithril.Fixtures.create_client()
    user = Mithril.Fixtures.create_user()

    Mithril.AppAPI.create_app(%{
      user_id: user.id,
      client_id: client.id,
      scope: "legal_entity:read legal_entity:write"
    })

    {:ok, refresh_token} = Mithril.Fixtures.create_refresh_token(client, user)

    assert refresh_token.name == "refresh_token"
    assert refresh_token.details.scope == ""

    {:ok, token} =
      RefreshTokenGrantType.authorize(%{
        "client_id" => client.id,
        "client_secret" => client.secret,
        "refresh_token" => refresh_token.value
      })

    assert token.name == "access_token"
    assert token.value
    assert token.expires_at
    assert token.user_id == user.id
    assert token.details.client_id == client.id
    assert token.details.grant_type == "refresh_token"
    assert token.details.scope == "legal_entity:read legal_entity:write"
  end

  test "it returns Request must include at least... error" do
    message = "Request must include at least client_id, client_secret and refresh_token parameters."
    assert {:error, {:unprocessable_entity, ^message}} = RefreshTokenGrantType.authorize(%{})
  end

  test "it returns invalid client id or secret error" do
    client = Mithril.Fixtures.create_client()

    message = "Invalid client id or secret."

    assert {:error, {:access_denied, %{message: ^message}}} =
             RefreshTokenGrantType.authorize(%{
               "client_id" => "F75029D0-DDBA-4897-A6F2-9A785222FD67",
               "client_secret" => client.secret,
               "refresh_token" => "some_value"
             })
  end

  test "it returns Token Not Found error" do
    client = Mithril.Fixtures.create_client()

    assert {:error, {:access_denied, errors}} =
             RefreshTokenGrantType.authorize(%{
               "client_id" => client.id,
               "client_secret" => client.secret,
               "refresh_token" => "some_token"
             })

    assert %{message: "Token not found.", type: "invalid_grant"} = errors
  end

  test "it returns Resource owner revoked access for the client error" do
    client = Mithril.Fixtures.create_client()
    user = Mithril.Fixtures.create_user()

    {:ok, refresh_token} = Mithril.Fixtures.create_refresh_token(client, user)

    message = "Resource owner revoked access for the client."

    assert {:error, {:access_denied, ^message}} =
             RefreshTokenGrantType.authorize(%{
               "client_id" => client.id,
               "client_secret" => client.secret,
               "refresh_token" => refresh_token.value
             })
  end

  test "it returns token expired error" do
    client = Mithril.Fixtures.create_client()
    user = Mithril.Fixtures.create_user()

    Mithril.AppAPI.create_app(%{
      user_id: user.id,
      client_id: client.id,
      scope: "legal_entity:read legal_entity:write"
    })

    {:ok, refresh_token} = Mithril.Fixtures.create_refresh_token(client, user, 0)

    assert {:error, {:access_denied, %{message: "Token expired.", type: "invalid_grant"}}} =
             RefreshTokenGrantType.authorize(%{
               "client_id" => client.id,
               "client_secret" => client.secret,
               "refresh_token" => refresh_token.value
             })
  end

  test "it returns token not found or expired error" do
    client = Mithril.Fixtures.create_client()
    user = Mithril.Fixtures.create_user()

    Mithril.AppAPI.create_app(%{
      user_id: user.id,
      client_id: client.id,
      scope: "legal_entity:read legal_entity:write"
    })

    client2 = Mithril.Fixtures.create_client(%{name: "Another name"})
    {:ok, refresh_token} = Mithril.Fixtures.create_refresh_token(client2, user)

    assert {:error, {:access_denied, %{type: "invalid_grant"}}} =
             RefreshTokenGrantType.authorize(%{
               "client_id" => client.id,
               "client_secret" => client.secret,
               "refresh_token" => refresh_token.value
             })
  end

  test "it returns error on missing values" do
    message = "Request must include at least client_id, client_secret and refresh_token parameters."

    {:error, {:unprocessable_entity, ^message}} =
      RefreshTokenGrantType.authorize(%{
        "client_id" => nil,
        "client_secret" => nil,
        "refresh_token" => nil
      })
  end
end
