defmodule Mithril.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: Mithril.Repo

  def create_code_grant_token(client, user, scope \\ "app:authorize", expires_at \\ 2_000_000_000) do
    insert(
      :token,
      details: %{
        scope_request: scope,
        client_id: client.id,
        grant_type: "password",
        redirect_uri: client.redirect_uri
      },
      user_id: user.id,
      expires_at: expires_at,
      name: "authorization_code",
      value: "some_short_lived_code"
    )
  end

  def create_refresh_token(client, user, expires_at \\ 2_000_000_000) do
    insert(
      :token,
      details: %{
        scope: "",
        client_id: client.id,
        grant_type: "authorization_code"
      },
      user_id: user.id,
      expires_at: expires_at,
      name: "refresh_token",
      value: "some_refresh_token_code"
    )
  end

  def create_access_token(client, user, expires_at \\ 2_000_000_000) do
    insert(
      :token,
      details: %{
        scope: "legal_entity:read legal_entity:write",
        client_id: client.id,
        grant_type: "refresh_token"
      },
      user_id: user.id,
      expires_at: expires_at,
      value: "some_access_token"
    )
  end

  def token_factory do
    user = insert(:user)
    client = insert(:client)

    %Mithril.TokenAPI.Token{
      details: %{
        "scope" => "app:authorize",
        "client_id" => client.id,
        "grant_type" => "password",
        "redirect_uri" => "http://localhost"
      },
      user_id: user.id,
      expires_at: 2_000_000_000,
      name: sequence("authorization_code-"),
      value: sequence("some_short_lived_code-")
    }
  end

  def client_factory do
    user = insert(:user)
    client_type = insert(:client_type)

    %Mithril.ClientAPI.Client{
      name: "some client",
      user_id: user.id,
      client_type_id: client_type.id,
      redirect_uri: "http://localhost",
      secret: sequence("secret-"),
      priv_settings: %{
        "access_type" => Mithril.ClientAPI.access_type(:direct)
      },
      is_blocked: false,
      block_reason: nil
    }
  end

  def client_type_factory do
    %Mithril.ClientTypeAPI.ClientType{
      name: sequence("some client_type name-"),
      scope: "some scope"
    }
  end

  def user_factory do
    %Mithril.UserAPI.User{
      email: sequence("mail@example.com-"),
      password: Comeonin.Bcrypt.hashpwsalt("Somepassword1"),
      password_set_at: NaiveDateTime.utc_now(),
      settings: %{},
      priv_settings: %Mithril.UserAPI.User.PrivSettings{
        login_hstr: [],
        otp_error_counter: 0
      },
      is_blocked: false,
      block_reason: nil
    }
  end

  def login_history_factory do
    %Mithril.UserAPI.User.LoginHstr{
      type: Mithril.Authorization.LoginHistory.type(:otp),
      is_success: true,
      time: ~N[2017-11-21 23:00:07]
    }
  end

  def role_factory do
    %Mithril.RoleAPI.Role{
      name: sequence("some name-"),
      scope: "some scope"
    }
  end

  def user_role_factory do
    %Mithril.UserRoleAPI.UserRole{
      user_id: insert(:user).id,
      client_id: insert(:client).id,
      role_id: insert(:role).id
    }
  end

  def app_factory do
    %Mithril.AppAPI.App{
      scope: "some scope",
      user_id: insert(:user).id,
      client_id: insert(:client).id
    }
  end

  def authentication_factor_factory do
    %Mithril.Authentication.Factor{
      type: Mithril.Authentication.type(:sms),
      factor: "+380901112233",
      is_active: true,
      user_id: insert(:user).id
    }
  end

  def otp_factory do
    expires =
      :seconds
      |> :os.system_time()
      |> Kernel.+(30)
      |> DateTime.from_unix!()
      |> DateTime.to_string()

    %Mithril.OTP.Schema{
      key: sequence("some-key-"),
      code: 1234,
      code_expired_at: expires,
      status: "NEW",
      active: true,
      attempts_count: 0
    }
  end
end
