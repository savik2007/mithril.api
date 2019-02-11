defmodule Core.Authorization.GrantType.RefreshTokenTest do
  use Core.DataCase, async: true

  alias Ecto.Changeset
  alias Core.Authorization.GrantType.RefreshToken, as: RefreshTokenGrantType

  describe "create refresh-granted access token" do
    setup do
      client = insert(:client)
      connection = insert(:connection, client: client)

      insert(:app,
        user: client.user,
        client: client,
        scope: "legal_entity:read legal_entity:write"
      )

      {:ok, %{client: client, user: client.user, connection: connection}}
    end

    test "success", %{client: client, user: user, connection: connection} do
      refresh_token = create_refresh_token(client, user)

      assert refresh_token.name == "refresh_token"
      assert refresh_token.details.scope == ""

      {:ok, token} =
        RefreshTokenGrantType.authorize(%{
          "client_id" => client.id,
          "client_secret" => connection.secret,
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

    test "it returns token expired error", %{client: client, user: user, connection: connection} do
      refresh_token = create_refresh_token(client, user, 0)

      assert {:error, {:access_denied, %{message: "Token expired.", type: "token_expired"}}} =
               RefreshTokenGrantType.authorize(%{
                 "client_id" => client.id,
                 "client_secret" => connection.secret,
                 "refresh_token" => refresh_token.value
               })
    end

    test "it returns token not found or expired error", %{
      client: client,
      user: user,
      connection: connection
    } do
      client2 = insert(:client, name: "Another name")
      refresh_token = create_refresh_token(client2, user)

      assert {:error, {:access_denied, %{type: "invalid_grant"}}} =
               RefreshTokenGrantType.authorize(%{
                 "client_id" => client.id,
                 "client_secret" => connection.secret,
                 "refresh_token" => refresh_token.value
               })
    end
  end

  test "it returns invalid client id or secret error" do
    client = insert(:client)
    connection = insert(:connection, client: client)

    message = "Invalid client id or secret."

    assert {:error, {:access_denied, %{message: ^message}}} =
             RefreshTokenGrantType.authorize(%{
               "client_id" => "F75029D0-DDBA-4897-A6F2-9A785222FD67",
               "client_secret" => connection.secret,
               "refresh_token" => "some_value"
             })
  end

  test "it returns Token Not Found error" do
    client = insert(:client)
    connection = insert(:connection, client: client)

    assert {:error, {:access_denied, errors}} =
             RefreshTokenGrantType.authorize(%{
               "client_id" => client.id,
               "client_secret" => connection.secret,
               "refresh_token" => "some_token"
             })

    assert %{message: "Token not found.", type: "token_not_found"} == errors
  end

  test "it returns Resource owner revoked access for the client error" do
    user = insert(:user)
    client = insert(:client)
    connection = insert(:connection, client: client)

    refresh_token = create_refresh_token(client, user)

    message = "Resource owner revoked access for the client."

    assert {:error, {:access_denied, ^message}} =
             RefreshTokenGrantType.authorize(%{
               "client_id" => client.id,
               "client_secret" => connection.secret,
               "refresh_token" => refresh_token.value
             })
  end

  describe "invalid params" do
    test "empty field values" do
      %Changeset{valid?: false} =
        RefreshTokenGrantType.authorize(%{
          "client_id" => nil,
          "client_secret" => nil,
          "refresh_token" => nil
        })
    end

    test "missed required fields" do
      assert %Changeset{valid?: false} = RefreshTokenGrantType.authorize(%{})
    end
  end
end
