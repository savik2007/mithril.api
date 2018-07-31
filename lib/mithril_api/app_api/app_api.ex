defmodule Mithril.AppAPI do
  @moduledoc """
  The boundary for the AppAPI system.
  """
  use Mithril.Search
  import Ecto.{Query, Changeset}, warn: false

  alias Ecto.Changeset
  alias Ecto.Multi
  alias Mithril.AppAPI.{App, AppSearch}
  alias Mithril.Repo
  alias Mithril.TokenAPI.Token

  def list_apps(params) do
    %AppSearch{}
    |> app_changeset(params)
    |> search_apps(params)
  end

  def get_app!(id) do
    App
    |> preload(:clients)
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
    with %Changeset{valid?: true, changes: changes} <- app_changeset(%AppSearch{}, params),
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

  defp app_changeset(%App{} = app, attrs) do
    app
    |> cast(attrs, [:user_id, :client_id, :scope])
    |> unique_constraint(:user_id, name: "apps_user_id_client_id_index")
    |> validate_required([:user_id, :client_id, :scope])
  end

  defp app_changeset(%AppSearch{} = app, attrs) do
    cast(app, attrs, [:user_id, :client_id])
  end
end
