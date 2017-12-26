defmodule Mithril.Ecto.Fixtures do
  @moduledoc false

  def ensure_fixtures do
    queries =
      create_or_update_client_types_queries() ++ create_or_update_roles_queries()

    Enum.each(queries, &Ecto.Adapters.SQL.query(Mithril.Repo, &1))
  end

  def create_or_update_client_types_queries do
    Enum.map [
      {"PHARMACY",      "client_types/pharmacy.txt"},
      {"MSP",           "client_types/msp.txt"},
      {"NHS ADMIN",     "client_types/nhs_admin.txt"},
      {"Mithril ADMIN", "client_types/mithril_admin.txt"},
      {"MIS",           "client_types/mis.txt"}
    ], fn {client_type_name, path} ->
      scope = read_scope_from_file(path)
      query = create_or_update_client_type_query(client_type_name, scope)
      sanitize_query(query)
    end
  end

  def create_or_update_roles_queries do
    Enum.map [
      {"DOCTOR",         "roles/doctor.txt"},
      {"NHS ADMIN",      "roles/nhs_admin.txt"},
      {"OWNER",          "roles/owner.txt"},
      {"ADMIN",          "roles/admin.txt"},
      {"PHARMACIST",     "roles/pharmacist.txt"},
      {"PHARMACY_OWNER", "roles/pharmacy_owner.txt"}
    ], fn {role_name, path} ->
      scope = read_scope_from_file(path)
      query = create_or_update_role_query(role_name, scope)
      sanitize_query(query)
    end
  end

  def create_or_update_client_type_query(client_type_name, scope) do
    "
      INSERT INTO client_types
        (id, name, scope, inserted_at, updated_at)
      VALUES
        (uuid_generate_v4(), '#{client_type_name}', '#{scope}', now(), now())
      ON CONFLICT (name) DO UPDATE
        SET scope = excluded.scope
    "
  end

  def create_or_update_role_query(role_name, scope) do
    "
      INSERT INTO roles
        (id, name, scope, inserted_at, updated_at)
      VALUES
        (uuid_generate_v4(), '#{role_name}', '#{scope}', now(), now())
      ON CONFLICT (name) DO UPDATE
        SET scope = excluded.scope
    "
  end

  defp read_scope_from_file(path) do
    path
    |> fixtures_dir()
    |> File.read!
    |> String.trim
    |> String.replace("\n", " ")
  end

  defp fixtures_dir(path) do
    Application.app_dir(:mithril_api, "priv/repo/fixtures/#{path}")
  end

  defp sanitize_query(query) do
    query
    |> String.replace("\r", "")
    |> String.replace("\n", "")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
end
