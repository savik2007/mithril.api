defmodule Mithril.Ecto.Fixtures do
  @moduledoc false

  def create_or_update_client_types_queries do
    Enum.map [
      {"PHARMACY", "pharmacy.txt"},
      {"MSP", "msp.txt"},
      {"NHS ADMIN", "nhs_admin.txt"},
      {"Mithril ADMIN", "mithril_admin.txt"},
      {"MIS", "mis.txt"}
    ], fn {client_type_name, filename} ->
      create_or_update_client_type_query(client_type_name, filename)
    end
  end

  def create_or_update_roles_queries do
    Enum.map [
      {"DOCTOR", "doctor.txt"},
      {"NHS ADMIN", "nhs_admin.txt"},
      {"OWNER", "owner.txt"},
      {"ADMIN", "admin.txt"},
      {"PHARMACIST", "pharmacist.txt"},
      {"PHARMACY_OWNER", "pharmacy_owner.txt"}
    ], fn {role_name, filename} ->
      create_or_update_role_query(role_name, filename)
    end
  end

  def create_or_update_client_type_query(client_type_name, filename) do
    scope = read_scope_from_file("client_types/#{filename}")

    "
      INSERT INTO client_types
        (id, name, scope, inserted_at, updated_at)
      VALUES
        (uuid_generate_v4(), '#{client_type_name}', '#{scope}', now(), now())
      ON CONFLICT (name) DO UPDATE
        SET scope = excluded.scope
    "
    |> sanitize_query()
  end

  def create_or_update_role_query(role_name, filename) do
    scope = read_scope_from_file("roles/#{filename}")

    "
      INSERT INTO roles
        (id, name, scope, inserted_at, updated_at)
      VALUES
        (uuid_generate_v4(), '#{role_name}', '#{scope}', now(), now())
      ON CONFLICT (name) DO UPDATE
        SET scope = excluded.scope
    "
    |> sanitize_query()
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
