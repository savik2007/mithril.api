defmodule Mithril.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: Mithril.Repo

  alias Ecto.UUID
  alias Comeonin.Bcrypt
  alias Mithril.AppAPI.App
  alias Mithril.Authentication
  alias Mithril.Authentication.Factor
  alias Mithril.Authorization.LoginHistory
  alias Mithril.Clients.Client
  alias Mithril.Clients.Connection
  alias Mithril.ClientTypeAPI.ClientType
  alias Mithril.GlobalUserRoleAPI.GlobalUserRole
  alias Mithril.OTP.Schema, as: OTP
  alias Mithril.RoleAPI.Role
  alias Mithril.TokenAPI.Token
  alias Mithril.UserAPI.User
  alias Mithril.UserAPI.User.LoginHstr
  alias Mithril.UserRoleAPI.UserRole

  def create_code_grant_token(connection, user, scope \\ "app:authorize", expires_at \\ 2_000_000_000) do
    insert(
      :token,
      details: %{
        scope_request: scope,
        client_id: connection.client.id,
        grant_type: "password",
        redirect_uri: connection.redirect_uri
      },
      user: user,
      expires_at: expires_at,
      name: "authorization_code",
      value: "some_short_lived_code"
    )
  end

  def create_refresh_token(%Client{} = client, user, expires_at \\ 2_000_000_000) do
    insert(
      :token,
      details: %{
        scope: "",
        client_id: client.id,
        grant_type: "authorization_code"
      },
      user: user,
      expires_at: expires_at,
      name: "refresh_token",
      value: "some_refresh_token_code"
    )
  end

  def create_access_token(%Client{} = client, user, expires_at \\ 2_000_000_000) do
    insert(
      :token,
      details: %{
        scope: "legal_entity:read legal_entity:write",
        client_id: client.id,
        grant_type: "refresh_token"
      },
      user: user,
      expires_at: expires_at,
      value: "some_access_token"
    )
  end

  def token_factory do
    client = insert(:client)

    %Token{
      details: %{
        "scope" => "app:authorize",
        "client_id" => client.id,
        "grant_type" => "password",
        "redirect_uri" => "http://localhost"
      },
      user: build(:user),
      expires_at: 2_000_000_000,
      name: sequence("authorization_code-"),
      value: sequence("some_short_lived_code-")
    }
  end

  def client_factory do
    %Client{
      name: sequence("ClinicN"),
      user: build(:user),
      client_type: build(:client_type),
      settings: %{
        "allowed_grant_types" => ["password"]
      },
      priv_settings: %{
        "access_type" => Client.access_type(:direct)
      },
      is_blocked: false,
      block_reason: nil
    }
  end

  def client_type_factory do
    %ClientType{
      name: sequence("some client_type name-"),
      scope: "app:authorize"
    }
  end

  def with_connection(client) do
    connection = insert(:connection, client: client)
    Map.put(client, :connections, [connection])
  end

  def connection_factory do
    %Connection{
      client: build(:client),
      consumer: build(:client),
      redirect_uri: "http://localhost",
      secret: sequence("secret-")
    }
  end

  def user_factory do
    %User{
      email: sequence("mail@example.com-"),
      tax_id: sequence("1234234"),
      password: user_raw_password() |> Bcrypt.hashpwsalt(),
      password_set_at: NaiveDateTime.utc_now(),
      settings: %{},
      priv_settings: %{
        login_hstr: [],
        otp_error_counter: 0
      },
      is_blocked: false,
      block_reason: nil,
      factor: nil,
      person_id: UUID.generate()
    }
  end

  def with_authentication_factor(user) do
    insert(:authentication_factor, user: user)
    user
  end

  def user_raw_password, do: "Somepassword1"

  def login_history_factory do
    %LoginHstr{
      type: LoginHistory.type(:otp),
      is_success: true,
      time: ~N[2017-11-21 23:00:07]
    }
  end

  def role_factory do
    %Role{
      name: sequence("some name-"),
      scope: "some scope"
    }
  end

  def user_role_factory do
    %UserRole{
      user: build(:user),
      client: build(:client),
      role: build(:role)
    }
  end

  def global_user_role_factory do
    %GlobalUserRole{
      user: build(:user),
      role: build(:role)
    }
  end

  def app_factory do
    %App{
      scope: "some scope",
      user: build(:user),
      client: build(:client)
    }
  end

  def authentication_factor_factory do
    %Factor{
      type: Authentication.type(:sms),
      factor: "+380901112233",
      is_active: true,
      user: build(:user)
    }
  end

  def otp_factory do
    expires =
      :seconds
      |> :os.system_time()
      |> Kernel.+(30)
      |> DateTime.from_unix!()
      |> DateTime.to_string()

    %OTP{
      key: sequence("some-key-"),
      code: 1234,
      code_expired_at: expires,
      status: "NEW",
      active: true,
      attempts_count: 0,
      inserted_at: DateTime.utc_now()
    }
  end
end
