defmodule Mithril.TokenAPI do
  @moduledoc false

  use Mithril.Search
  import Ecto.{Query, Changeset}, warn: false

  alias Mithril.Repo
  alias Mithril.ClientAPI
  alias Mithril.TokenAPI.Token
  alias Mithril.ClientAPI.Client
  alias Mithril.TokenAPI.TokenSearch

  @direct ClientAPI.access_type(:direct)
  @broker ClientAPI.access_type(:broker)

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
    from e in entity,
      where: ^params,
      where: fragment("? @> ?", e.details, ^details_params)
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

  def create_access_token(attrs \\ %{}) do
    %Token{}
    |> access_token_changeset(attrs)
    |> Repo.insert()
  end

  def update_token(%Token{} = token, attrs) do
    token
    |> token_changeset(attrs)
    |> Repo.update()
  end

  def delete_token(%Token{} = token) do
    Repo.delete(token)
  end

  def delete_tokens_by_params(params) do
    %TokenSearch{}
    |> token_changeset(params)
    |> case do
         %Ecto.Changeset{valid?: true, changes: changes} ->
           Token |> get_search_query(changes) |> Repo.delete_all()

         changeset
         -> changeset
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
        message = "Token expired or client approval was revoked."
        Mithril.Authorization.GrantType.Error.invalid_grant(message)
    end
  end

  def verify_client_token(token_value, api_key) do
    token = get_token_by_value!(token_value)

    with false <- expired?(token),
         _app <- Mithril.AppAPI.approval(token.user_id, token.details["client_id"]),
         client <- ClientAPI.get_client!(token.details["client_id"]),
         :ok <- check_client_is_blocked(client),
         {:ok, token} <- put_broker_scopes(token, client, api_key) do
      {:ok, token}
    else
      {:error, _, _} = err ->
        err
      _ ->
        message = "Token expired or client approval was revoked."
        Mithril.Authorization.GrantType.Error.invalid_grant(message)
    end
  end

  def expired?(%Token{} = token) do
    token.expires_at < :os.system_time(:seconds)
  end

  defp put_broker_scopes(token, client, api_key) do
    case Map.get(client.priv_settings, "access_type") do
      nil -> {:error, %{invalid_client: "Client settings must contain access_type."}, :unprocessable_entity}

      # Clients such as NHS Admin, MIS
      @direct -> {:ok, token}

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
  defp validate_api_key(_), do: {:error, %{api_key: "API-KEY header required."}, :unprocessable_entity}

  defp fetch_client_by_secret({:error, errors, status}), do: {:error, errors, status}
  defp fetch_client_by_secret(api_key) do
    case ClientAPI.get_client_by([secret: api_key]) do
      %ClientAPI.Client{} = client -> client
      _ ->
        {:error, %{api_key: "API-KEY header is invalid."}, :unprocessable_entity}
    end
  end

  defp fetch_broker_scope({:error, errors, status}), do: {:error, errors, status}
  defp fetch_broker_scope(%ClientAPI.Client{priv_settings: %{"broker_scope" => broker_scope}}) do
    broker_scope
  end
  defp fetch_broker_scope(_) do
    {:error, %{broker_settings: "Incorrect broker settings."}, :unprocessable_entity}
  end

  defp put_broker_scope_into_token_details({:error, errors, status}, _token), do: {:error, errors, status}
  defp put_broker_scope_into_token_details(broker_scope, token) do
    details = Map.put(token.details, "broker_scope", broker_scope)
    {:ok, Map.put(token, :details, details)}
  end

  def deactivate_old_tokens(%Token{id: id, user_id: user_id}) do
    now = :os.system_time(:seconds)
    Token
    |> where([t], t.id != ^id)
    |> where([t], t.name == "access_token" and t.user_id == ^user_id)
    |> where([t], t.expires_at >= ^now)
    |> where([t], fragment("?->>'grant_type' = 'password'", t.details))
    |> Repo.update_all(set: [expires_at: now])
  end

  @uuid_regex ~r|[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}|

  defp token_changeset(%Token{} = token, attrs) do
    token
    |> cast(attrs, [:name, :user_id, :value, :expires_at, :details])
    |> validate_format(:user_id, @uuid_regex)
    |> validate_required([:name, :user_id, :value, :expires_at, :details])
  end

  defp token_changeset(%TokenSearch{} = token, attrs) do
    token
    |> cast(attrs, [:name, :value, :user_id, :client_id])
    |> validate_format(:user_id, @uuid_regex)
    |> set_like_attributes([:name, :value])
  end

  defp refresh_token_changeset(%Token{} = token, attrs) do
    token
    |> cast(attrs, [:name, :expires_at, :details, :user_id])
    |> validate_required([:user_id])
    |> put_change(:value, SecureRandom.urlsafe_base64)
    |> put_change(:name, "refresh_token")
    |> put_change(:expires_at, :os.system_time(:seconds) + Map.fetch!(get_token_lifetime(), :refresh))
    |> unique_constraint(:value, name: :tokens_value_name_index)
  end

  defp access_token_changeset(%Token{} = token, attrs) do
    token
    |> cast(attrs, [:name, :expires_at, :details, :user_id])
    |> validate_required([:user_id])
    |> put_change(:value, SecureRandom.urlsafe_base64)
    |> put_change(:name, "access_token")
    |> put_change(:expires_at, :os.system_time(:seconds) + Map.fetch!(get_token_lifetime(), :access))
    |> unique_constraint(:value, name: :tokens_value_name_index)
  end

  defp authorization_code_changeset(%Token{} = token, attrs) do
    token
    |> cast(attrs, [:name, :expires_at, :details, :user_id])
    |> validate_required([:user_id])
    |> put_change(:value, SecureRandom.urlsafe_base64)
    |> put_change(:name, "authorization_code")
    |> put_change(:expires_at, :os.system_time(:seconds) + Map.fetch!(get_token_lifetime(), :code))
    |> unique_constraint(:value, name: :tokens_value_name_index)
  end

  defp get_token_lifetime,
    do: Confex.fetch_env!(:mithril_api, :token_lifetime)

  defp check_client_is_blocked(%Client{is_blocked: false}), do: :ok
  defp check_client_is_blocked(_) do
    {:error, %{invalid_client: "Authentication failed"}, :unauthorized}
  end
end
