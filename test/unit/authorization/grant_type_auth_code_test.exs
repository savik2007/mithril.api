defmodule Mithril.Authorization.GrantType.AuthorizationCodeTest do
  use Mithril.DataCase, async: true

  alias Mithril.Authorization.GrantType.AuthorizationCode, as: AuthorizationCodeGrantType

  test "creates code-granted access token" do
    client = Mithril.Fixtures.create_client()
    user   = Mithril.Fixtures.create_user()

    Mithril.AppAPI.create_app(%{
      user_id: user.id,
      client_id: client.id,
      scope: "legal_entity:read legal_entity:write"
    })

    {:ok, code_grant} = Mithril.Fixtures.create_code_grant_token(client, user, "legal_entity:read")

    {:ok, token} = AuthorizationCodeGrantType.authorize(%{
      "client_id" => client.id,
      "client_secret" => client.secret,
      "code" => code_grant.value,
      "redirect_uri" => client.redirect_uri <> "?world"
    })

    assert token.name == "access_token"
    assert token.value
    assert token.expires_at
    assert token.user_id == user.id
    assert token.details.client_id == client.id
    assert token.details.refresh_token
    assert token.details.grant_type == "authorization_code"
    assert token.details.redirect_uri == client.redirect_uri
    assert token.details.scope == "legal_entity:read"

    assert true = Mithril.TokenAPI.get_token!(code_grant.id).details["used"]
  end

  test "it returns Request must include at least... error" do
    message = "Request must include at least client_id, client_secret, code and redirect_uri parameters."
    assert {:error, {:unprocessable_entity, ^message}} = AuthorizationCodeGrantType.authorize(%{
      "scope" => "legal_entity:read"
    })
  end

  test "it returns invalid client id or secret error" do
    client = Mithril.Fixtures.create_client()

    message = "Invalid client id or secret."
    assert {:error, {:access_denied, %{message: ^message, type: "invalid_client"}}} =
             AuthorizationCodeGrantType.authorize(%{
      "client_id" => "F75029D0-DDBA-4897-A6F2-9A785222FD67",
      "client_secret" => client.secret,
      "code" => "some_code",
      "redirect_uri" => client.redirect_uri,
      "scope" => "legal_entity:read"
    })
  end

  test "it returns Token Not Found error" do
    client = Mithril.Fixtures.create_client()

    assert {:error, {:access_denied, errors}} = AuthorizationCodeGrantType.authorize(%{
      "client_id" => client.id,
      "client_secret" => client.secret,
      "code" => "some_code",
      "redirect_uri" => client.redirect_uri,
      "scope" => "legal_entity:read"
    })

    assert %{message: "Token not found."} = errors
  end

  test "it returns Resource owner revoked access for the client error" do
    client = Mithril.Fixtures.create_client()
    user   = Mithril.Fixtures.create_user()

    {:ok, code_grant} = Mithril.Fixtures.create_code_grant_token(client, user)

    message = "Resource owner revoked access for the client."
    assert {:error, {:access_denied, ^message}} = AuthorizationCodeGrantType.authorize(%{
      "client_id" => client.id,
      "client_secret" => client.secret,
      "code" => code_grant.value,
      "redirect_uri" => client.redirect_uri,
      "scope" => "legal_entity:read"
    })
  end

  test "it returns redirection URI client error" do
    client = Mithril.Fixtures.create_client()
    user   = Mithril.Fixtures.create_user()

    Mithril.AppAPI.create_app(%{
      user_id: user.id,
      client_id: client.id,
      scope: "legal_entity:read legal_entity:write"
    })

    {:ok, code_grant} = Mithril.Fixtures.create_code_grant_token(client, user)

    message = "The redirection URI provided does not match a pre-registered value."
    assert {:error, {:access_denied, %{message: ^message}}} = AuthorizationCodeGrantType.authorize(%{
      "client_id" => client.id,
      "client_secret" => client.secret,
      "code" => code_grant.value,
      "redirect_uri" => "some_suspicios_uri",
      "scope" => "legal_entity:read"
    })
  end

  test "it returns token expired error" do
    client = Mithril.Fixtures.create_client()
    user   = Mithril.Fixtures.create_user()
    scope  = "legal_entity:read legal_entity:write"

    Mithril.AppAPI.create_app(%{
      user_id: user.id,
      client_id: client.id,
      scope: scope
    })

    {:ok, code_grant} = Mithril.Fixtures.create_code_grant_token(client, user, scope, 0)

    message = "Token expired."
    assert {:error, {:access_denied, %{message: ^message}}} = AuthorizationCodeGrantType.authorize(%{
      "client_id" => client.id,
      "client_secret" => client.secret,
      "code" => code_grant.value,
      "redirect_uri" => client.redirect_uri,
      "scope" => "legal_entity:read"
    })
  end

  test "it returns token not found or expired error" do
    client = Mithril.Fixtures.create_client()
    user   = Mithril.Fixtures.create_user()

    Mithril.AppAPI.create_app(%{
      user_id: user.id,
      client_id: client.id,
      scope: "legal_entity:read legal_entity:write"
    })

    client2 = Mithril.Fixtures.create_client(%{name: "Another name"})
    {:ok, code_grant} = Mithril.Fixtures.create_code_grant_token(client2, user)

    message = "Token not found or expired."
    assert {:error, {:access_denied, %{message: ^message, type: "invalid_grant"}}} =
             AuthorizationCodeGrantType.authorize(%{
      "client_id" => client.id,
      "client_secret" => client.secret,
      "code" => code_grant.value,
      "redirect_uri" => client.redirect_uri,
      "scope" => "legal_entity:read"
    })
  end

  test "it returns token was used error" do
    client = Mithril.Fixtures.create_client()
    user   = Mithril.Fixtures.create_user()

    Mithril.AppAPI.create_app(%{
      user_id: user.id,
      client_id: client.id,
      scope: "legal_entity:read legal_entity:write"
    })

    {:ok, code_grant} = Mithril.Fixtures.create_code_grant_token(client, user)
    {:ok, code_grant} =
      Mithril.TokenAPI.update_token(code_grant, %{details: Map.put_new(code_grant.details, :used, true)})

    message = "Token has already been used."
    assert {:error, {:access_denied, ^message}} = AuthorizationCodeGrantType.authorize(%{
      "client_id" => client.id,
      "client_secret" => client.secret,
      "code" => code_grant.value,
      "redirect_uri" => client.redirect_uri,
      "scope" => "legal_entity:read"
    })

  end

  test "it returns error on missing values" do
    message = "Request must include at least client_id, client_secret, code and redirect_uri parameters."

    assert {:error, {:unprocessable_entity, ^message}} = AuthorizationCodeGrantType.authorize(%{
      "client_id" => nil,
      "client_secret" => nil,
      "code" => nil,
      "redirect_uri" => nil,
      "scope" => nil
    })
  end
end
