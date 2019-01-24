defmodule Mithril.AppAPI do
  @moduledoc """
  The boundary for the AppAPI system.
  """
  import Mithril.Search
  import Ecto.{Query, Changeset}

  alias Ecto.Changeset
  alias Ecto.Multi
  alias Mithril.AppAPI.{App, AppSearch}
  alias Mithril.Repo
  alias Mithril.TokenAPI.Token
  alias Mithril.UserAPI.User

  def list_apps(params) do
    %AppSearch{}
    |> app_search_changeset(params)
    |> search_apps(params)
  end

  def search_apps(%Ecto.Changeset{valid?: true}, %{"user_id" => user_id} = params) do
    with %{} = search_params <-
           params
           |> Map.take(~w(client_ids client_names))
           |> Enum.map(fn {k, v} -> convert_search_param(k, v) end)
           |> validate_query_params() do
      search_params = Map.put(search_params, "user_id", user_id)

      App
      |> preload(:client)
      |> apply_filters(search_params)
      |> Repo.paginate(params)
    end
  end

  def search_apps(%Ecto.Changeset{valid?: false} = changeset, _params) do
    {:error, changeset}
  end

  defp apply_filters(query, params) when map_size(params) > 0 do
    ids = get_search_param(params, "client_ids")
    names = get_search_param(params, "client_names")
    user_id = params["user_id"]

    query =
      query
      |> join(:inner, [a], c in assoc(a, :client))
      |> join(:inner, [a], u in User, u.id == a.user_id and u.id == ^user_id)

    query =
      Enum.reduce(ids, query, fn id, query ->
        or_where(query, [_, c, _], c.id == ^id)
      end)

    Enum.reduce(names, query, fn value, query ->
      or_where(query, [_, c, _], ilike(c.name, ^(value <> "%")))
    end)
  end

  defp apply_filters(query, _), do: query

  defp get_search_param(params, param_name) do
    Map.get(params, param_name, [])
  end

  defp validate_query_params(params) do
    Enum.reduce_while(params, %{}, fn
      {true, name, values}, %{} = params ->
        {:cont, Map.put(params, name, values)}

      _, _ ->
        {:halt, {:error, :not_found}}
    end)
  end

  defp convert_search_param(param_name, value) do
    value
    |> get_comma_params(AppSearch.prefix(param_name))
    |> validate_param(param_name)
  end

  defp get_comma_params(param, prefix) do
    param
    |> String.split(",")
    |> Enum.map(&(&1 |> String.split(prefix) |> Enum.at(1)))
    |> Enum.filter(&(!is_nil(&1)))
  end

  defp validate_param(values, "client_ids") do
    valid? = not Enum.any?(values, fn uuid -> :error == Ecto.UUID.cast(uuid) end)
    {valid?, "client_ids", values}
  end

  defp validate_param(values, param_name), do: {true, param_name, values}

  def get_app!(id) do
    App
    |> preload(:client)
    |> Repo.get!(id)
  end

  def get_app_by(attrs), do: Repo.get_by(App, attrs)

  def create_app(attrs \\ %{}) do
    %App{}
    |> app_changeset(attrs)
    |> Repo.insert()
  end

  def update_app(%App{} = app, attrs) do
    app
    |> app_changeset(attrs)
    |> Repo.update()
  end

  def delete_app(%App{} = app) do
    Multi.new()
    |> Multi.delete(:delete_apps, app)
    |> Multi.run(:expire_tokens, &deactivate_old_tokens(&1))
    |> Repo.transaction()
  end

  def delete_apps_by_params(params) do
    Multi.new()
    |> Multi.run(:delete_apps, fn _ -> delete_apps(params) end)
    |> Multi.run(:expire_tokens, &deactivate_old_tokens(&1))
    |> Repo.transaction()
  end

  defp delete_apps(params) do
    with %Changeset{valid?: true, changes: changes} <- app_delete_changeset(%App{}, params),
         {_, nil} <- App |> get_search_query(changes) |> Repo.delete_all() do
      {:ok, changes}
    end
  end

  defp deactivate_old_tokens(%{delete_apps: %{user_id: user_id} = expire_params}) do
    now = :os.system_time(:seconds)

    with {_, nil} <-
           Token
           |> where([t], t.expires_at >= ^now)
           |> where([t], t.user_id == ^user_id)
           |> where_token_client(expire_params)
           |> Repo.update_all(set: [expires_at: now]) do
      {:ok, expire_params}
    end
  end

  defp where_token_client(query, %{client_id: client_id}) when is_binary(client_id) do
    where(query, [t], fragment("?->>'client_id' = ?", t.details, ^client_id))
  end

  defp where_token_client(query, _), do: query

  def change_app(%App{} = app) do
    app_changeset(app, %{})
  end

  def approval(user_id, client_id) do
    get_app_by(user_id: user_id, client_id: client_id)
  end

  defp app_delete_changeset(%App{} = app, attrs) do
    cast(app, attrs, [:user_id, :client_id])
  end

  defp app_changeset(%App{} = app, attrs) do
    app
    |> cast(attrs, [:user_id, :client_id, :scope])
    |> unique_constraint(:user_id, name: "apps_user_id_client_id_index")
    |> validate_required([:user_id, :client_id, :scope])
  end

  defp app_search_changeset(%AppSearch{} = app, attrs) do
    cast(app, attrs, AppSearch.__schema__(:fields))
  end
end
