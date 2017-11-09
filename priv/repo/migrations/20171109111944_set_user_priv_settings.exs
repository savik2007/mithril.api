defmodule Mithril.Repo.Migrations.SetUserPrivSettings do
  use Ecto.Migration

  def change do
    sql = """
      UPDATE users
      SET priv_settings = '{"login_error_counter": 0, "otp_error_counter": 0}'
    """
    execute sql
  end
end
