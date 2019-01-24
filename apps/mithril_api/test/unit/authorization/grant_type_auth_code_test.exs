defmodule Mithril.Authorization.GrantType.AuthorizationCodeTest do
  use Mithril.DataCase, async: true

  alias Ecto.Changeset
  alias Mithril.TokenAPI
  alias Mithril.Authorization.GrantType.AuthorizationCode, as: AuthorizationCodeGrantType

  test "creates code-granted access token" do
    client = insert(:client)

    insert(:connection, client: client)
    insert(:connection, client: client)
    redirect_uri = "https://example.com/redirect_uri"
    connection = insert(:connection, client: client, redirect_uri: redirect_uri)

    insert(:app,
      user: client.user,
      client: client,
      scope: "legal_entity:read legal_entity:write"
    )

    code_grant = create_code_grant_token(connection, client.user, "legal_entity:read")

    {:ok, token} =
      AuthorizationCodeGrantType.authorize(%{
        "client_id" => client.id,
        "client_secret" => connection.secret,
        "code" => code_grant.value,
        "redirect_uri" => redirect_uri <> "?world"
      })

    assert token.name == "access_token"
    assert token.value
    assert token.expires_at
    assert token.user_id == client.user.id
    assert token.details.client_id == client.id
    assert token.details.refresh_token
    assert token.details.grant_type == "authorization_code"
    assert token.details.redirect_uri == redirect_uri
    assert token.details.scope == "legal_entity:read"

    assert true = TokenAPI.get_token!(code_grant.id).details["used"]
  end

  test "it returns invalid client id or secret error on invalid client_id" do
    client = insert(:client)
    connection = insert(:connection, client: client)

    message = "Invalid client id or secret."

    assert {:error, {:access_denied, %{message: ^message, type: "invalid_client"}}} =
             AuthorizationCodeGrantType.authorize(%{
               "client_id" => "F75029D0-DDBA-4897-A6F2-9A785222FD67",
               "client_secret" => connection.secret,
               "code" => "some_code",
               "redirect_uri" => connection.redirect_uri,
               "scope" => "legal_entity:read"
             })
  end

  test "it returns invalid client id or secret error on invalid secret" do
    client = insert(:client)
    connection = insert(:connection, client: client)

    message = "Invalid client id or secret."

    assert {:error, {:access_denied, %{message: ^message, type: "invalid_client"}}} =
             AuthorizationCodeGrantType.authorize(%{
               "client_id" => client.id,
               "client_secret" => "invalid secret",
               "code" => "some_code",
               "redirect_uri" => connection.redirect_uri,
               "scope" => "legal_entity:read"
             })
  end

  test "it returns Token Not Found error" do
    client = insert(:client)
    connection = insert(:connection, client: client)

    assert {:error, {:access_denied, errors}} =
             AuthorizationCodeGrantType.authorize(%{
               "client_id" => client.id,
               "client_secret" => connection.secret,
               "code" => "some_code",
               "redirect_uri" => connection.redirect_uri,
               "scope" => "legal_entity:read"
             })

    assert %{message: "Token not found."} = errors
  end

  test "it returns Resource owner revoked access for the client error" do
    client = insert(:client)
    connection = insert(:connection, client: client)
    code_grant = create_code_grant_token(connection, client.user)

    message = "Resource owner revoked access for the client."

    assert {:error, {:access_denied, ^message}} =
             AuthorizationCodeGrantType.authorize(%{
               "client_id" => client.id,
               "client_secret" => connection.secret,
               "code" => code_grant.value,
               "redirect_uri" => connection.redirect_uri,
               "scope" => "legal_entity:read"
             })
  end

  describe "invalid redirect_uri" do
    test "it returns redirection URI client error when redirect_uri not matched with token redirect_uri" do
      client = insert(:client)
      connection = insert(:connection, client: client)

      insert(:app,
        user: client.user,
        client: client,
        scope: "legal_entity:read legal_entity:write"
      )

      token_data = %{client: %{id: connection.client_id}, redirect_uri: "https://example.com/invalid"}
      code_grant = create_code_grant_token(token_data, client.user)

      message = "The redirection URI provided does not match a pre-registered value."

      assert {:error, {:access_denied, %{message: ^message}}} =
               AuthorizationCodeGrantType.authorize(%{
                 "client_id" => client.id,
                 "client_secret" => connection.secret,
                 "code" => code_grant.value,
                 "redirect_uri" => connection.redirect_uri,
                 "scope" => "legal_entity:read"
               })
    end

    test "it returns redirection URI client error when redirect_uri not matched with connection redirect_uri" do
      client = insert(:client)
      connection = insert(:connection, client: client, redirect_uri: "https://example1.com")
      connection2 = insert(:connection, client: client, redirect_uri: "https://example2.com")

      insert(:app,
        user: client.user,
        client: client,
        scope: "legal_entity:read legal_entity:write"
      )

      code_grant = create_code_grant_token(connection, client.user)

      message = "The redirection URI provided does not match a pre-registered value."

      assert {:error, {:access_denied, %{message: ^message}}} =
               AuthorizationCodeGrantType.authorize(%{
                 "client_id" => client.id,
                 "client_secret" => connection2.secret,
                 "code" => code_grant.value,
                 "redirect_uri" => connection.redirect_uri,
                 "scope" => "legal_entity:read"
               })
    end
  end

  test "it returns token expired error" do
    client = insert(:client)
    connection = insert(:connection, client: client)
    scope = "legal_entity:read legal_entity:write"

    insert(:app,
      user: client.user,
      client: client,
      scope: scope
    )

    code_grant = create_code_grant_token(connection, client.user, scope, 0)

    message = "Token expired."

    assert {:error, {:access_denied, %{message: ^message}}} =
             AuthorizationCodeGrantType.authorize(%{
               "client_id" => client.id,
               "client_secret" => connection.secret,
               "code" => code_grant.value,
               "redirect_uri" => connection.redirect_uri,
               "scope" => "legal_entity:read"
             })
  end

  test "it returns token not found or expired error" do
    client = insert(:client)
    connection = insert(:connection, client: client)

    insert(:app,
      user: client.user,
      client: client,
      scope: "legal_entity:read legal_entity:write"
    )

    client2 = insert(:client, name: "Another name")
    connection2 = insert(:connection, client: client2)
    code_grant = create_code_grant_token(connection2, client2.user)

    message = "Token not found or expired."

    assert {:error, {:access_denied, %{message: ^message, type: "invalid_grant"}}} =
             AuthorizationCodeGrantType.authorize(%{
               "client_id" => client.id,
               "client_secret" => connection.secret,
               "code" => code_grant.value,
               "redirect_uri" => connection.redirect_uri,
               "scope" => "legal_entity:read"
             })
  end

  test "it returns token was used error" do
    client = insert(:client)
    connection = insert(:connection, client: client)

    insert(:app,
      user: client.user,
      client: client,
      scope: "legal_entity:read legal_entity:write"
    )

    code_grant = create_code_grant_token(connection, client.user)

    {:ok, code_grant} = TokenAPI.update_token(code_grant, %{details: Map.put_new(code_grant.details, :used, true)})

    message = "Token has already been used."

    assert {:error, {:access_denied, ^message}} =
             AuthorizationCodeGrantType.authorize(%{
               "client_id" => client.id,
               "client_secret" => connection.secret,
               "code" => code_grant.value,
               "redirect_uri" => connection.redirect_uri,
               "scope" => "legal_entity:read"
             })
  end

  describe "invalid params" do
    test "empty field values" do
      assert %Changeset{valid?: false} =
               AuthorizationCodeGrantType.authorize(%{
                 "client_id" => nil,
                 "client_secret" => nil,
                 "code" => nil,
                 "redirect_uri" => nil,
                 "scope" => nil
               })
    end

    test "missed required fields" do
      assert %Changeset{valid?: false} = AuthorizationCodeGrantType.authorize(%{"scope" => "legal_entity:read"})
    end
  end
end
