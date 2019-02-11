defmodule Core.Repo.Migrations.SetClientsPrivSettings do
  use Ecto.Migration

  def change do
    # set DIRECT access_type for all clients except MSP and PHARMACY
    sql = """
      UPDATE clients
      SET priv_settings = '{"access_type": "DIRECT"}'
      FROM client_types
      WHERE client_types.name NOT IN('MSP', 'PHARMACY')
      AND clients.client_type_id = client_types.id;
    """

    execute(sql)

    # set BROKER access_type for MSP and PHARMACY clients
    sql = """
      UPDATE clients
      SET priv_settings = '{"access_type": "BROKER"}'
      FROM client_types
      WHERE client_types.name IN('MSP', 'PHARMACY')
      AND clients.client_type_id = client_types.id;
    """

    execute(sql)
  end
end
