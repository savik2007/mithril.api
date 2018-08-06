defmodule Mithril.TokenAPI do
  @moduledoc false

  import Mithril.Search
  import Ecto.{Query, Changeset}

  alias Mithril.Authorization.GrantType
  alias Mithril.ClientAPI
  alias Mithril.Error
  alias Mithril.Repo
  alias Mithril.TokenAPI
  alias Mithril.TokenAPI.Token
  alias Mithril.TokenAPI.TokenSearch
  alias Mithril.UserAPI
  alias Mithril.UserAPI.User

  @uuid_regex ~r|[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}|

  @refresh_token "refresh_token"
  @access_token "access_token"
  @access_token_2fa "2fa_access_token"
  @change_password_token "change_password_token"
  @authorization_code "authorization_code"

  def access_token_2fa, do: @access_token_2fa
  def change_password_token, do: @change_password_token

  def token_type(:refresh), do: @refresh_token
  def token_type(:access), do: @access_token
  def token_type(:access_2fa), do: @access_token_2fa
  def token_type(:change_password), do: @change_password_token
  def token_type(:authorization_code), do: @authorization_code

  def list_tokens(params) do
    %TokenSearch{}
    |> token_changeset(params)
    |> search_token(params)
  end

  def search_token(%Ecto.Changeset{valid?: true, changes: changes}, params) do
    Token
    |> get_token_search_query(changes)
    |> Repo.paginate(params)
  end

  def search_token(%Ecto.Changeset{valid?: false} = changeset, _search_params) do
    {:error, changeset}
  end

  def get_token_search_query(entity, %{client_id: client_id} = changes) do
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

  def get_token_search_query(entity, changes), do: get_search_query(entity, changes)

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
         :ok <- GrantType.validate_client_allowed_grant_types(client, "password"),
         :ok <- GrantType.validate_client_allowed_scope(client, scope),
         {:ok, token} <- create_access_token(user, client, scope),
         {_, nil} <- TokenAPI.deactivate_old_tokens(token) do
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
        Token |> get_token_search_query(changes) |> Repo.delete_all()

      changeset ->
        changeset
    end
  end

  def change_token(%Token{} = token) do
    token_changeset(token, %{})
  end

  def expired?(%Token{} = token) do
    token.expires_at <= :os.system_time(:seconds)
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
    |> cast(attrs, TokenSearch.__schema__(:fields))
    |> validate_format(:user_id, @uuid_regex)
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
end
