defmodule Mithril.Authorization.GrantType.PasswordTest do
  use Mithril.DataCase, async: true

  alias Mithril.UserAPI
  alias Mithril.Authorization.GrantType.Password, as: PasswordGrantType

  test "creates password-granted access token" do
    System.put_env("USER_2FA_ENABLED", "false")

    allowed_scope = "app:authorize legal_entity:read legal_entity:write"
    client_type = Mithril.Fixtures.create_client_type(%{scope: allowed_scope})
    client = Mithril.Fixtures.create_client(%{
      settings: %{"allowed_grant_types" => ["password"]},
      client_type_id: client_type.id
    })
    user = Mithril.Fixtures.create_user(%{password: "somepa$$word"})

    {:ok,  %{token: token}} = PasswordGrantType.authorize(%{
      "email" => user.email,
      "password" => "somepa$$word",
      "client_id" => client.id,
      "scope" => "legal_entity:read",
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
    password = "somepa$$word"
    user = insert(:user, password: Comeonin.Bcrypt.hashpwsalt(password))
    client_type = insert(:client_type, scope: allowed_scope)
    client = insert(:client,
      user_id: user.id,
      client_type_id: client_type.id,
      settings: %{"allowed_grant_types" => ["password"]}
    )
    insert(:authentication_factor, user_id: user.id)

    {:ok, %{token: token}} = PasswordGrantType.authorize(%{
      "email" => user.email,
      "password" => password,
      "client_id" => client.id,
      "scope" => "legal_entity:read",
    })

    assert token.name == "2fa_access_token"
  end

  test "it returns Incorrect password error" do
    client = Mithril.Fixtures.create_client(%{settings: %{"allowed_grant_types" => ["password"]}})
    user   = Mithril.Fixtures.create_user(%{password: "somepa$$word"})

    {:error, errors, code} = PasswordGrantType.authorize(%{
      "email" => user.email,
      "password" => "incorrect_password",
      "client_id" => client.id,
      "scope" => "legal_entity:read",
    })

    assert %{invalid_grant: "Identity, password combination is wrong."} = errors
    assert :unauthorized = code
  end

  test "user blocked when reached max login errors" do
    client = Mithril.Fixtures.create_client(%{settings: %{"allowed_grant_types" => ["password"]}})
    user   = Mithril.Fixtures.create_user(%{password: "somepa$$word"})
    data = %{
      "email" => user.email,
      "password" => "incorrect_password",
      "client_id" => client.id,
      "scope" => "legal_entity:read",
    }
    for _ <- 1..4 do
      assert {:error, _, _} = PasswordGrantType.authorize(data)
    end

    assert %{is_blocked: true} = UserAPI.get_user(user.id)
  end

  test "it returns User Not Found error" do
    client = Mithril.Fixtures.create_client(%{settings: %{"allowed_grant_types" => ["password"]}})

    {:error, errors, code} = PasswordGrantType.authorize(%{
      "email" => "non_existing_email",
      "password" => "incorrect_password",
      "client_id" => client.id,
      "scope" => "legal_entity:read",
    })

    assert %{invalid_grant: "Identity not found."} = errors
    assert :unauthorized = code
  end

  test "it returns Client Not Found error" do
    user = Mithril.Fixtures.create_user(%{password: "somepa$$word"})

    {:error, errors, code} = PasswordGrantType.authorize(%{
      "email" => user.email,
      "password" => "somepa$$word",
      "client_id" => "391374D3-A05D-403B-9290-E0BAAC5CCA21",
      "scope" => "legal_entity:read"
    })

    assert %{invalid_client: "Invalid client id."} = errors
    assert :unauthorized = code
  end

  test "it returns Incorrect Scopes error" do
    allowed_scope = "app:authorize legal_entity:read legal_entity:write"
    client_type = Mithril.Fixtures.create_client_type(%{scope: allowed_scope})
    client = Mithril.Fixtures.create_client(%{
      settings: %{"allowed_grant_types" => ["password"]},
      client_type_id: client_type.id
    })
    user = Mithril.Fixtures.create_user(%{password: "somepa$$word"})

    {:error, errors, code} = PasswordGrantType.authorize(%{
      "email" => user.email,
      "password" => "somepa$$word",
      "client_id" => client.id,
      "scope" => "some_hidden_api:read",
    })

    message = "Allowed scopes for the token are #{Enum.join(String.split(allowed_scope), ", ")}."
    assert %{invalid_scope: ^message} = errors
    assert :bad_request = code
  end

  test "it returns insufficient parameters error" do
    {:error, errors, code} = PasswordGrantType.authorize(%{})

    message = "Request must include at least email, password, client_id and scope parameters."
    assert %{invalid_request: ^message} = errors
    assert :bad_request = code
  end

  test "it returns error on missing values" do
    {:error, errors, code} = PasswordGrantType.authorize(%{
      "email" => nil,
      "password" => nil,
      "client_id" => nil,
      "scope" => nil
    })

    message = "Request must include at least email, password, client_id and scope parameters."
    assert %{invalid_request: ^message} = errors
    assert :bad_request = code
  end

  describe "authorize login errors" do
    setup do
      user = insert(:user, password: Comeonin.Bcrypt.hashpwsalt("somepa$$word"))
      client_type = insert(:client_type, scope: "app:authorize, legal_entity:read")
      client = insert(:client,
        user_id: user.id,
        client_type_id: client_type.id,
        settings: %{"allowed_grant_types" => ["password"]}
      )
      %{user: user, client: client}
    end

    test "user blocked when reached max failed logins", %{user: user, client: client} do
      user_login_error_max = Confex.get_env(:mithril_api, :"2fa")[:user_login_error_max]
      data = %{
        "email" => user.email,
        "password" => "invalid",
        "client_id" => client.id,
        "scope" => "legal_entity:read",
      }
      for _ <- 1..(user_login_error_max - 1) do
        assert {:error, _, :unauthorized} = PasswordGrantType.authorize(data)
      end
      # user have last attempt for success login
      refute UserAPI.get_user!(user.id).is_blocked

      assert {:error, _, :unauthorized} = PasswordGrantType.authorize(data)
      # now user blocked
      db_user = UserAPI.get_user!(user.id)
      assert db_user.is_blocked
      assert user_login_error_max == db_user.priv_settings.login_error_counter

      assert {:error, {:access_denied, "User blocked."}} =
               data
               |> Map.put("password", "somepa$$word")
               |> PasswordGrantType.authorize()
    end

    test "user login error counter refreshed after success login", %{user: user, client: client} do
      data = %{
        "email" => user.email,
        "password" => "invalid",
        "client_id" => client.id,
        "scope" => "legal_entity:read",
      }
      for _ <- 1..2 do
        assert {:error, _, :unauthorized} = PasswordGrantType.authorize(data)
      end
      assert {:ok, _} =
               data
               |> Map.put("password", "somepa$$word")
               |> PasswordGrantType.authorize()

      db_user = UserAPI.get_user!(user.id)
      refute db_user.is_blocked
      assert 0 == db_user.priv_settings.login_error_counter
    end
  end
end
