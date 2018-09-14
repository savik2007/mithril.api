defmodule Mithril.Repo.Migrations.MigrateCientsDataToConnections do
  use Ecto.Migration
  alias Ecto.Adapters.SQL
  alias Ecto.UUID
  alias Mithril.Repo

  def up do
    msp_clients = %{
      "https://reform.helsi.me" => "7fb21983-0e7d-41dd-9769-568793dcabf1",
      "http://e-life.com.ua" => "d410cd00-9cd4-44f7-b92d-5dbe8570431c",
      "https://org.medcard24.net/e-health/oauth/redirect" => "987330f9-f6df-4d27-a96c-73230f99cc1c",
      "https://newmedicine.com.ua" => "383066aa-fef4-480b-b524-6bded845c876",
      "https://medics.com.ua" => "57581d41-4620-430a-9ac6-a8c95b116156",
      "https://ehealth.mcplus.com.ua/people/auth" => "9f554755-de5c-43bc-abbb-61fa2cbdad87",
      "https://eh-srv.mcmed.ua" => "23672642-90c3-4d91-b0ec-b33455ff2e1c",
      "https://askep.net" => "cb1c2802-e2d8-40fc-b699-1405db7ef53d",
      "https://93.183.206.83" => "23672642-90c3-4d91-b0ec-b33455ff2e1c",
      "https://account.health24.life/api/services/app/authMoz/Authorize" => "28fd03c5-1789-467a-a9d0-f1626f2dfa32",
      "https://ehealth.vikisoft.kiev.ua/employee-request" => "face8b90-56c1-49a0-98a7-2780a20b2d86",
      "https://portalauth.e-life.com.ua" => "d410cd00-9cd4-44f7-b92d-5dbe8570431c",
      "https://portal-doctor.eleks.com" => "119be6a5-4506-4112-a1e8-750e4642a9ee",
      "https://brovary.eh-srv.mcmed.ua" => "23672642-90c3-4d91-b0ec-b33455ff2e1c"
    }

    Enum.each(msp_clients, fn {uri, consumer_id} ->
      sql = "SELECT id, secret, redirect_uri FROM clients WHERE redirect_uri ILIKE '%#{uri}%';"

      case SQL.query(Repo, sql, []) do
        {:ok, %{num_rows: num_rows, rows: rows}} when num_rows > 0 ->
          insert_msp_connections(rows, consumer_id)

        _ ->
          :ok
      end
    end)

    sql = """
      SELECT c1.id, c1.secret, c1.redirect_uri
      FROM clients AS c1
      LEFT JOIN connections AS c2 ON c1.id = c2.client_id
      WHERE c2.client_id IS NULL;
    """

    case SQL.query(Repo, sql, []) do
      {:ok, %{num_rows: num_rows, rows: rows}} when num_rows > 0 ->
        insert_mis_connections(rows)

      _ ->
        :ok
    end
  end

  defp insert_msp_connections(clients, consumer_id) do
    values =
      clients
      |> Enum.reduce("", fn [client_id, secret, redirect_uri], acc ->
        client_id = UUID.cast!(client_id)
        acc <> "(
            uuid_generate_v4(),
            '#{secret}',
            '#{client_id}',
            '#{consumer_id}',
            '#{redirect_uri}',
            NOW(),
            NOW()
          ),"
      end)
      |> String.trim(",")

    sql = """
      INSERT INTO connections(id, secret, client_id, consumer_id, redirect_uri, inserted_at, updated_at)
      VALUES #{values};
    """

    {:ok, _} = SQL.query(Repo, sql, [])
  end

  defp insert_mis_connections([]), do: :ok

  defp insert_mis_connections([[client_id, secret, redirect_uri] | tail]) do
    sql = """
      INSERT INTO connections(id, secret, client_id, consumer_id, redirect_uri, inserted_at, updated_at)
      VALUES (uuid_generate_v4(), $1, $2, $3, $4, NOW(), NOW());
    """

    {:ok, _} = SQL.query(Repo, sql, [secret, client_id, client_id, redirect_uri])
    insert_mis_connections(tail)
  end

  def down do
    sql = "TRUNCATE connections"
    execute(sql)
  end
end
