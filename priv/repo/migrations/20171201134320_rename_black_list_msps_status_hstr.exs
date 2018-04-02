defmodule Mithril.Repo.Migrations.RenameBlackListMspsStatusHstr do
  use Ecto.Migration

  def up do
    rename(table(:black_list_msps_status_hstr_id_seq), to: table(:clients_block_reason_hstr_id_seq))
    rename(table(:black_list_msps_status_hstr), to: table(:clients_block_reason_hstr))

    execute("DROP TRIGGER IF EXISTS on_black_list_msps_insert ON clients;")
    execute("DROP TRIGGER IF EXISTS on_black_list_msps_update ON clients;")
    execute("DROP FUNCTION IF EXISTS insert_black_list_msps_status_hstr();")

    execute("""
    CREATE OR REPLACE FUNCTION insert_clients_block_reason_hstr()
    RETURNS trigger AS
    $BODY$
    BEGIN
    INSERT INTO clients_block_reason_hstr(legal_entity_id,is_blocked,block_reason,inserted_at)
    VALUES(NEW.id,NEW.is_blocked,NEW.block_reason,now());

    RETURN NEW;
    END;
    $BODY$
    LANGUAGE plpgsql;
    """)

    execute("""
    CREATE TRIGGER on_clients_block_reason_insert
    AFTER INSERT
    ON clients
    FOR EACH ROW
    EXECUTE PROCEDURE insert_clients_block_reason_hstr();
    """)

    execute("""
    CREATE TRIGGER on_clients_block_reason_update
    AFTER UPDATE
    ON clients
    FOR EACH ROW
    WHEN (OLD.block_reason IS DISTINCT FROM NEW.block_reason OR
          OLD.is_blocked IS DISTINCT FROM NEW.is_blocked)
    EXECUTE PROCEDURE insert_clients_block_reason_hstr();
    """)
  end

  def down do
    execute("DROP TRIGGER IF EXISTS on_clients_block_reason_insert ON clients;")
    execute("DROP TRIGGER IF EXISTS on_clients_block_reason_update ON clients;")
    execute("DROP FUNCTION IF EXISTS insert_clients_block_reason_hstr();")

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

    rename(table(:clients_block_reason_hstr_id_seq), to: table(:black_list_msps_status_hstr_id_seq))
    rename(table(:clients_block_reason_hstr), to: table(:black_list_msps_status_hstr))
  end
end
