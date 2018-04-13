defmodule Mithril.Authorization.GrantType.PasswordTest do
  use Mithril.DataCase, async: false

  alias Mithril.UserAPI
  alias Mithril.Authorization.GrantType.Password, as: PasswordGrantType

  test "creates password-granted access token" do
    System.put_env("USER_2FA_ENABLED", "false")

    allowed_scope = "app:authorize legal_entity:read legal_entity:write"
    client_type = insert(:client_type, scope: allowed_scope)

    client =
      insert(
        :client,
        settings: %{"allowed_grant_types" => ["password"]},
        client_type_id: client_type.id
      )

    user = insert(:user, password: Comeonin.Bcrypt.hashpwsalt("Somepa$$word1"))

    {:ok, %{token: token}} =
      PasswordGrantType.authorize(%{
        "email" => user.email,
        "password" => "Somepa$$word1",
        "client_id" => client.id,
        "scope" => "legal_entity:read"
      })

    assert token.name == "access_token"
    assert token.value
    assert token.expires_at
    assert token.user_id == user.id
    assert token.details["client_id"] == client.id
    assert token.details["grant_type"] == "password"
    assert token.details["redirect_uri"] == client.redirect_uri
    assert token.details["scope"] == "legal_entity:read"

    System.put_env("USER_2FA_ENABLED", "true")
  end

  test "creates password-granted 2FA access token" do
    allowed_scope = "app:authorize legal_entity:read legal_entity:write"
    password = "Somepa$$word1"
    user = insert(:user, password: Comeonin.Bcrypt.hashpwsalt(password))
    client_type = insert(:client_type, scope: allowed_scope)

    client =
      insert(
        :client,
        user_id: user.id,
        client_type_id: client_type.id,
        settings: %{"allowed_grant_types" => ["password"]}
      )

    insert(:authentication_factor, user_id: user.id)

    {:ok, %{token: token}} =
      PasswordGrantType.authorize(%{
        "email" => user.email,
        "password" => password,
        "client_id" => client.id,
        "scope" => "legal_entity:read"
      })

    assert token.name == "2fa_access_token"
  end

  test "it returns Incorrect password error" do
    client = insert(:client, settings: %{"allowed_grant_types" => ["password"]})
    user = insert(:user, password: Comeonin.Bcrypt.hashpwsalt("Somepa$$word1"))

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

    assert {:error, {:access_denied, "Identity, password combination is wrong."}} =
             PasswordGrantType.authorize(%{
               "email" => "non_existing_email",
               "password" => "incorrect_password",
               "client_id" => client.id,
               "scope" => "legal_entity:read"
             })
  end

  test "it returns Client Not Found error" do
    user = insert(:user, password: Comeonin.Bcrypt.hashpwsalt("Somepa$$word1"))

    assert {:error, {:access_denied, "Invalid client id."}} =
             PasswordGrantType.authorize(%{
               "email" => user.email,
               "password" => "Somepa$$word1",
               "client_id" => "391374D3-A05D-403B-9290-E0BAAC5CCA21",
               "scope" => "legal_entity:read"
             })
  end

  test "it returns Incorrect Scopes error" do
    allowed_scope = "app:authorize legal_entity:read legal_entity:write"
    client_type = insert(:client_type, scope: allowed_scope)

    client =
      insert(
        :client,
        settings: %{"allowed_grant_types" => ["password"]},
        client_type_id: client_type.id
      )

    user = insert(:user, password: Comeonin.Bcrypt.hashpwsalt("Somepa$$word1"))
    message = "Allowed scopes for the token are #{Enum.join(String.split(allowed_scope), ", ")}."

    assert {:error, {:access_denied, ^message}} =
             PasswordGrantType.authorize(%{
               "email" => user.email,
               "password" => "Somepa$$word1",
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
      user = insert(:user, password: Comeonin.Bcrypt.hashpwsalt("somepa$$word"))
      client_type = insert(:client_type, scope: "app:authorize, legal_entity:read")

      client =
        insert(
          :client,
          user_id: user.id,
          client_type_id: client_type.id,
          settings: %{"allowed_grant_types" => ["password"]}
        )

      %{user: user, client: client}
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
               |> Map.put("password", "somepa$$word")
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
               |> Map.put("password", "somepa$$word")
               |> PasswordGrantType.authorize()

      db_user = UserAPI.get_user!(user.id)
      refute db_user.is_blocked
      assert [] == db_user.priv_settings.login_hstr
    end
  end
end
