defmodule Mithril.Repo.Migrations.AddDefaultData do
  use Ecto.Migration

  import Mithril.Ecto.Fixtures

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"")

    create_or_update_client_types()
    create_or_update_roles()
  end

  defp create_or_update_client_types do
    Enum.each(create_or_update_client_types_queries(), &execute(&1))
  end

  defp create_or_update_roles do
    Enum.each(create_or_update_roles_queries(), &execute(&1))
  end

  def down do
  end
end
