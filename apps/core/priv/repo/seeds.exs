# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Core.Repo.insert!(%Mithril.SomeModel{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will halt execution if something goes wrong.

defmodule Seeder do
  alias Core.Repo
  alias Core.RoleAPI.Role
  alias Core.Clients.Client
  alias Core.ClientTypeAPI.ClientType

  def seed do
    [
      {%Role{}, "/roles.json"},
      {%ClientType{}, "/client_types.json"},
      {%Client{}, "/clients.json"}
    ]
    |> Enum.each(&seed_file/1)
  end

  defp seed_file({schema, file}) do
    file
    |> seed_file_path()
    |> File.read!()
    |> Poison.decode!(as: [schema])
    |> Enum.map(&insert_or_update!/1)
  end

  defp insert_or_update!(%Client{seed?: true} = schema) do
    Repo.insert!(
      schema,
      on_conflict: prepare_on_conflict(schema),
      conflict_target: :id
    )
  end

  defp insert_or_update!(%{seed?: true} = schema) do
    Repo.insert!(
      schema,
      on_conflict: prepare_on_conflict(schema),
      conflict_target: :name
    )
  end

  defp insert_or_update!(_schema), do: :skipped

  defp prepare_on_conflict(schema) do
    not_for_update = ~w(id inserted_at updated_at)a

    update =
      :fields
      |> schema.__struct__.__schema__()
      |> Enum.reject(fn elem -> elem in not_for_update end)
      |> Enum.map(fn field ->
        {field, Map.get(schema, field)}
      end)

    [set: update]
  end

  defp seed_file_path(file) do
    :core
    |> Application.app_dir("priv/repo/seeds")
    |> Kernel.<>(file)
  end
end

Seeder.seed()
