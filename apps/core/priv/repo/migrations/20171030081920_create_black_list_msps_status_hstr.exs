defmodule Core.Repo.Migrations.CreateBlackListMspsStatusHstr do
  use Ecto.Migration

  def up do
    create table(:black_list_msps_status_hstr) do
      add(:legal_entity_id, :uuid, null: false)
      add(:is_blocked, :boolean, null: false)
      add(:block_reason, :string)
      timestamps(type: :utc_datetime, updated_at: false)
    end

    execute("""
    CREATE OR REPLACE FUNCTION insert_black_list_msps_status_hstr()
    RETURNS trigger AS
    $BODY$
    BEGIN
    INSERT INTO black_list_msps_status_hstr(legal_entity_id,is_blocked,block_reason,inserted_at)
    VALUES(NEW.id,NEW.is_blocked,NEW.block_reason,now());

    RETURN NEW;
    END;
    $BODY$
    LANGUAGE plpgsql;
    """)

    execute("""
    CREATE TRIGGER on_black_list_msps_insert
    AFTER INSERT
    ON clients
    FOR EACH ROW
    EXECUTE PROCEDURE insert_black_list_msps_status_hstr();
    """)

    execute("""
    CREATE TRIGGER on_black_list_msps_update
    AFTER UPDATE
    ON clients
    FOR EACH ROW
    WHEN (OLD.block_reason IS DISTINCT FROM NEW.block_reason OR
          OLD.is_blocked IS DISTINCT FROM NEW.is_blocked)
    EXECUTE PROCEDURE insert_black_list_msps_status_hstr();
    """)
  end

  def down do
    execute("DROP TRIGGER IF EXISTS on_black_list_msps_insert ON clients;")
    execute("DROP TRIGGER IF EXISTS on_black_list_msps_update ON clients;")
    execute("DROP FUNCTION IF EXISTS insert_black_list_msps_status_hstr();")

    drop(table(:black_list_msps_status_hstr))
  end
end
