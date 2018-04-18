defmodule Mithril.TokenAPI do
  @moduledoc false

  use Mithril.Search
  import Ecto.{Query, Changeset}, warn: false

  alias Mithril.{Repo, Error, Guardian}
  alias Mithril.{UserAPI, ClientAPI}
  alias Mithril.UserAPI.User
  alias Mithril.TokenAPI.Token
  alias Mithril.ClientAPI.Client
  alias Mithril.TokenAPI.TokenSearch
  alias Mithril.Authentication
  alias Mithril.Authentication.Factor
  alias Mithril.Authorization.GrantType.{Password, AccessToken2FA}
  alias Ecto.Multi

  @direct ClientAPI.access_type(:direct)
  @broker ClientAPI.access_type(:broker)

  @refresh_token "refresh_token"
  @access_token "access_token"
  @access_token_2fa "2fa_access_token"
  @change_password_token "change_password_token"
  @authorization_code "authorization_code"

  @type_field "request_authentication_factor_type"
  @factor_field "request_authentication_factor"

  def list_tokens(params) do
    %TokenSearch{}
    |> token_changeset(params)
    |> search(params, Token)
  end

  def get_search_query(entity, %{client_id: client_id} = changes) do
    params =
      changes
      |> Map.delete(:client_id)
      |> Map.to_list()

    details_params = %{client_id: client_id}

    from(
      e in entity,
      where: ^params,
      where: fragment("? @> ?", e.details, ^details_params)
    )
  end

  def get_search_query(entity, changes), do: super(entity, changes)

  def get_token!(id), do: Repo.get!(Token, id)

  def get_token_by_value!(value), do: Repo.get_by!(Token, value: value)
  def get_token_by(attrs), do: Repo.get_by(Token, attrs)

  def create_token(attrs \\ %{}) do
    %Token{}
    |> token_changeset(attrs)
    |> Repo.insert()
  end

  # TODO: create refresh and auth token in transaction
  def create_refresh_token(attrs \\ %{}) do
    %Token{}
    |> refresh_token_changeset(attrs)
    |> Repo.insert()
  end

  def create_authorization_code(attrs \\ %{}) do
    %Token{}
    |> authorization_code_changeset(attrs)
    |> Repo.insert()
  end

  def create_access_token(%User{} = user, %{"client_id" => client_id, "scope" => scope}) do
    with client <- ClientAPI.get_client_with_type(client_id),
         :ok <- Password.validate_client(client, "password"),
         :ok <- Password.validate_token_scope_by_client(client.client_type.scope, scope),
         {:ok, token} <- create_access_token(user, client, scope),
         {_, nil} <- Mithril.TokenAPI.deactivate_old_tokens(token) do
      {:ok, token}
    end
  end

  def create_access_token(_, _), do: {:error, {:"422", "invalid params"}}

  def create_access_token(user, client, scope) do
    data = %{
      user_id: user.id,
      details: %{
        "grant_type" => "password",
        "client_id" => client.id,
        "scope" => scope,
        "redirect_uri" => client.redirect_uri
      }
    }

    create_access_token(data)
  end

  def create_access_token(attrs \\ %{}) do
    %Token{}
    |> access_token_changeset(attrs)
    |> Repo.insert()
  end

  def create_2fa_access_token(attrs \\ %{}) do
    %Token{}
    |> access_token_2fa_changeset(attrs)
    |> Repo.insert()
  end

  def create_change_password_token(attrs \\ %{}) do
    %Token{}
    |> change_password_token_changeset(attrs)
    |> Repo.insert()
  end

  def update_user_password(%{"user" => user} = attrs) do
    with {:ok, token} <- validate_token(attrs["token_value"]),
         :ok <- validate_change_pwd_token(token),
         {:ok, user} <- UserAPI.update_user_password(token.user_id, user["password"]),
         do: {:ok, user}
  end

  defp validate_token(token_value) do
    with %Token{} = token <- get_token_by(value: token_value),
         false <- expired?(token) do
      {:ok, token}
    else
      true -> Error.token_expired()
      nil -> Error.token_invalid()
    end
  end

  defp validate_change_pwd_token(%Token{name: @change_password_token}), do: :ok
  defp validate_change_pwd_token(_), do: Error.token_invalid_type()

  def update_token(%Token{} = token, attrs) do
    token
    |> token_changeset(attrs)
    |> Repo.update()
  end

  def delete_token(%Token{} = token) do
    Repo.delete(token)
  end

  def delete_tokens_by_user_ids(user_ids) do
    q = from(t in Token, where: t.user_id in ^user_ids)
    Repo.delete_all(q)
  end

  def delete_tokens_by_params(params) do
    %TokenSearch{}
    |> token_changeset(params)
    |> case do
      %Ecto.Changeset{valid?: true, changes: changes} ->
        Token |> get_search_query(changes) |> Repo.delete_all()

      changeset ->
        changeset
    end
  end

  def change_token(%Token{} = token) do
    token_changeset(token, %{})
  end

  def verify(token_value) do
    token = get_token_by_value!(token_value)

    with false <- expired?(token),
         _app <- Mithril.AppAPI.approval(token.user_id, token.details["client_id"]) do
      # if token is authorization_code or password - make sure was not used previously
      {:ok, token}
    else
      _ ->
        Error.invalid_grant("Token expired or client approval was revoked.")
    end
  end

  def verify_client_token(token_value, api_key) do
    token = get_token_by_value!(token_value)

    with false <- expired?(token),
         _app <- Mithril.AppAPI.approval(token.user_id, token.details["client_id"]),
         client <- ClientAPI.get_client!(token.details["client_id"]),
         :ok <- check_client_is_blocked(client),
         user <- UserAPI.get_user!(token.user_id),
         :ok <- check_user_is_blocked(user),
         {:ok, token} <- put_broker_scopes(token, client, api_key) do
      {:ok, token}
    else
      {:error, _} = err -> err
      _ -> Error.invalid_grant("Token expired or client approval was revoked.")
    end
  end

  def expired?(%Token{} = token) do
    token.expires_at <= :os.system_time(:seconds)
  end

  defp put_broker_scopes(token, client, api_key) do
    case Map.get(client.priv_settings, "access_type") do
      nil ->
        Error.access_denied("Client settings must contain access_type.")

      # Clients such as NHS Admin, MIS
      @direct ->
        {:ok, token}

      # Clients such as MSP, PHARMACY
      @broker ->
        api_key
        |> validate_api_key()
        |> fetch_client_by_secret()
        |> fetch_broker_scope()
        |> put_broker_scope_into_token_details(token)
    end
  end

  defp validate_api_key(api_key) when is_binary(api_key), do: api_key
  defp validate_api_key(_), do: Error.invalid_request("API-KEY header required.")

  defp fetch_client_by_secret({:error, _} = err), do: err

  defp fetch_client_by_secret(api_key) do
    case ClientAPI.get_client_by(secret: api_key) do
      %ClientAPI.Client{} = client ->
        client

      _ ->
        Error.invalid_request("API-KEY header is invalid.")
    end
  end

  defp fetch_broker_scope({:error, _} = err), do: err

  defp fetch_broker_scope(%ClientAPI.Client{priv_settings: %{"broker_scope" => broker_scope}}) do
    broker_scope
  end

  defp fetch_broker_scope(_) do
    Error.invalid_request("Incorrect broker settings.")
  end

  defp put_broker_scope_into_token_details({:error, _} = err, _token), do: err

  defp put_broker_scope_into_token_details(broker_scope, token) do
    details = Map.put(token.details, "broker_scope", broker_scope)
    {:ok, Map.put(token, :details, details)}
  end

  def deactivate_tokens_by_user(%User{id: id}) do
    now = :os.system_time(:seconds)

    Token
    |> where([t], t.user_id == ^id)
    |> where([t], t.expires_at >= ^now)
    |> Repo.update_all(set: [expires_at: now])
  end

  def deactivate_old_tokens(%Token{id: id, user_id: user_id, name: name, details: details}) do
    now = :os.system_time(:seconds)

    Token
    |> where([t], t.id != ^id)
    |> where([t], t.user_id == ^user_id)
    |> deactivate_old_tokens_where_name_clause(name)
    |> where([t], t.expires_at >= ^now)
    |> where([t], fragment("?->>'client_id' = ?", t.details, ^details["client_id"]))
    |> Repo.update_all(set: [expires_at: now])
  end

  defp deactivate_old_tokens_where_name_clause(query, name) when name in [@access_token, @access_token_2fa] do
    where(query, [t], t.name in [@access_token, @access_token_2fa])
  end

  defp deactivate_old_tokens_where_name_clause(query, name) do
    where(query, [t], t.name == ^name)
  end

  def deactivate_old_password_tokens do
    expiration_days = Confex.get_env(:mithril_api, :password)[:expiration]

    query =
      Token
      |> join(:inner, [t], u in User, t.user_id == u.id)
      |> where([t], t.name not in ["2fa_access_token", "change_password_token"])
      |> where([t], t.expires_at >= ^:os.system_time(:seconds))
      |> where([t, u], fragment("now() >= ?", datetime_add(u.password_set_at, ^expiration_days, "day")))

    Multi.new()
    |> Multi.update_all(:tokens, query, set: [expires_at: :os.system_time(:seconds)])
    |> Repo.transaction()
  end

  @uuid_regex ~r|[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}|

  defp token_changeset(%Token{} = token, attrs) do
    token
    |> cast(attrs, [:name, :user_id, :value, :expires_at, :details])
    |> validate_format(:user_id, @uuid_regex)
    |> validate_required([:name, :user_id, :value, :expires_at, :details])
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:value, name: :tokens_value_name_index)
  end

  defp token_changeset(%TokenSearch{} = token, attrs) do
    token
    |> cast(attrs, [:name, :value, :user_id, :client_id])
    |> validate_format(:user_id, @uuid_regex)
    |> set_like_attributes([:name, :value])
  end

  defp token_changeset(%Token{} = token, attrs, type, name) do
    token
    |> cast(attrs, [:name, :expires_at, :details, :user_id])
    |> validate_required([:user_id])
    |> put_change(:value, SecureRandom.urlsafe_base64())
    |> put_change(:name, name)
    |> put_change(:expires_at, :os.system_time(:seconds) + Map.fetch!(get_token_lifetime(), type))
    |> unique_constraint(:value, name: :tokens_value_name_index)
  end

  defp refresh_token_changeset(%Token{} = token, attrs) do
    token_changeset(token, attrs, :refresh, @refresh_token)
  end

  defp access_token_changeset(%Token{} = token, attrs) do
    token_changeset(token, attrs, :access, @access_token)
  end

  defp access_token_2fa_changeset(%Token{} = token, attrs) do
    token_changeset(token, attrs, :access, @access_token_2fa)
  end

  defp change_password_token_changeset(%Token{} = token, attrs) do
    token_changeset(token, attrs, :access, @change_password_token)
  end

  defp authorization_code_changeset(%Token{} = token, attrs) do
    token_changeset(token, attrs, :code, @authorization_code)
  end

  defp get_token_lifetime, do: Confex.fetch_env!(:mithril_api, :token_lifetime)

  defp check_client_is_blocked(%Client{is_blocked: false}), do: :ok

  defp check_client_is_blocked(_) do
    Error.invalid_client("Authentication failed.")
  end

  defp check_user_is_blocked(%User{is_blocked: false}), do: :ok

  defp check_user_is_blocked(_) do
    Error.invalid_user("Authentication failed.")
  end

  def generate_nonce_for_client([client_id]) when is_binary(client_id) do
    ttl = {Confex.fetch_env!(:mithril_api, :ttl_login), :minutes}

    with %{is_blocked: false} <- ClientAPI.get_client!(client_id) do
      Guardian.encode_and_sign(:nonce, %{nonce: 123}, token_type: "access", ttl: ttl)
    else
      %{is_blocked: true} -> {:error, {:access_denied, "Client is blocked"}}
    end
  end

  def generate_nonce_for_client(_), do: {:error, {:access_denied, "Client header not set"}}
end
