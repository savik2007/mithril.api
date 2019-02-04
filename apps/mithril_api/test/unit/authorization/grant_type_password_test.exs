defmodule Mithril.Authorization.GrantType.PasswordTest do
  use Mithril.DataCase, async: true

  alias Mithril.UserAPI
  alias Mithril.Authorization.GrantType.Password, as: PasswordGrantType

  @password user_raw_password()

  test "creates password-granted access token" do
    System.put_env("USER_2FA_ENABLED", "false")

    allowed_scope = "app:authorize legal_entity:read legal_entity:write"
    client_type = insert(:client_type, scope: allowed_scope)
    user = insert(:user)
    client = insert(:client, client_type: client_type)

    {:ok, %{token: token}} =
      PasswordGrantType.authorize(%{
        "email" => user.email,
        "password" => @password,
        "client_id" => client.id,
        "scope" => "legal_entity:read"
      })

    assert token.name == "access_token"
    assert token.value
    assert token.expires_at
    assert token.user_id == user.id
    assert token.details["client_id"] == client.id
    assert token.details["grant_type"] == "password"
    assert token.details["scope"] == "legal_entity:read"

    on_exit(fn -> System.put_env("USER_2FA_ENABLED", "true") end)
  end

  test "creates password-granted 2FA access token" do
    allowed_scope = "app:authorize legal_entity:read legal_entity:write"
    user = insert(:user)
    client_type = insert(:client_type, scope: allowed_scope)
    client = insert(:client, user: user, client_type: client_type)
    insert(:authentication_factor, user: user)

    {:ok, %{token: token}} =
      PasswordGrantType.authorize(%{
        "email" => user.email,
        "password" => @password,
        "client_id" => client.id,
        "scope" => "legal_entity:read"
      })

    assert token.name == "2fa_access_token"
  end

  test "it returns Incorrect password error" do
    client = insert(:client, settings: %{"allowed_grant_types" => ["password"]})
    user = insert(:user)

    assert {:error, {:access_denied, "Identity, password combination is wrong."}} =
             PasswordGrantType.authorize(%{
               "email" => user.email,
               "password" => "incorrect_password",
               "client_id" => client.id,
               "scope" => "legal_entity:read"
             })
  end

  test "it returns Incorrect password error when invalid email" do
    client = insert(:client, settings: %{"allowed_grant_types" => ["password"]})

    assert {:error, {:access_denied, "User not found."}} =
             PasswordGrantType.authorize(%{
               "email" => "non_existing_email",
               "password" => "incorrect_password",
               "client_id" => client.id,
               "scope" => "legal_entity:read"
             })
  end

  test "it returns Client Not Found error" do
    user = insert(:user)

    assert {:error, {:access_denied, %{message: "Invalid client id.", type: "invalid_client"}}} =
             PasswordGrantType.authorize(%{
               "email" => user.email,
               "password" => @password,
               "client_id" => "391374D3-A05D-403B-9290-E0BAAC5CCA21",
               "scope" => "legal_entity:read"
             })
  end

  test "it returns Incorrect Scopes error" do
    allowed_scope = "app:authorize legal_entity:read legal_entity:write"
    client_type = insert(:client_type, scope: allowed_scope)
    user = insert(:user)
    client = insert(:client, client_type: client_type)

    message = "Scope is not allowed by client type."

    assert {:error, {:unprocessable_entity, ^message}} =
             PasswordGrantType.authorize(%{
               "email" => user.email,
               "password" => @password,
               "client_id" => client.id,
               "scope" => "some_hidden_api:read"
             })
  end

  test "it returns insufficient parameters error" do
    assert %Ecto.Changeset{valid?: false} = PasswordGrantType.authorize(%{})
  end

  test "it returns error on missing values" do
    assert %Ecto.Changeset{valid?: false} =
             PasswordGrantType.authorize(%{
               "email" => nil,
               "password" => nil,
               "client_id" => nil,
               "scope" => nil
             })
  end

  describe "authorize login errors" do
    setup do
      client_type = insert(:client_type, scope: "app:authorize, legal_entity:read")
      client = insert(:client, client_type: client_type)

      %{user: client.user, client: client}
    end

    test "user blocked when reached max failed logins", %{user: user, client: client} do
      user_login_error_max = Confex.get_env(:mithril_api, :password)[:max_failed_logins]

      data = %{
        "email" => user.email,
        "password" => "invalid",
        "client_id" => client.id,
        "scope" => "legal_entity:read"
      }

      for _ <- 1..user_login_error_max do
        assert {:error, {:access_denied, _}} = PasswordGrantType.authorize(data)
      end

      db_user = UserAPI.get_user!(user.id)
      assert user_login_error_max == length(db_user.priv_settings.login_hstr)

      assert {:error, {:access_denied, "You reached login attempts limit. Try again later"}} =
               data
               |> Map.put("password", @password)
               |> PasswordGrantType.authorize()
    end

    test "user login error counter refreshed after success login", %{user: user, client: client} do
      data = %{
        "email" => user.email,
        "password" => "invalid",
        "client_id" => client.id,
        "scope" => "legal_entity:read"
      }

      for _ <- 1..2 do
        assert {:error, {:access_denied, _}} = PasswordGrantType.authorize(data)
      end

      assert {:ok, _} =
               data
               |> Map.put("password", @password)
               |> PasswordGrantType.authorize()

      db_user = UserAPI.get_user!(user.id)
      refute db_user.is_blocked
      assert [] == db_user.priv_settings.login_hstr
    end
  end
end
