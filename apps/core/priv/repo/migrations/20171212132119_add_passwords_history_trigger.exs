defmodule Core.Repo.Migrations.AddPasswordsHistoryTrigger do
  use Ecto.Migration

  def up do
    execute("""
      CREATE OR REPLACE FUNCTION insert_password_hstr()
        RETURNS trigger AS
      $BODY$
      BEGIN
          INSERT INTO password_hstr(user_id,password,inserted_at)
          VALUES(NEW.id,NEW.password,now());

          RETURN NEW;
      END;
      $BODY$
      LANGUAGE plpgsql;
    """)

    execute("""
    CREATE TRIGGER on_user_insert
    AFTER INSERT
    ON users
    FOR EACH ROW
    EXECUTE PROCEDURE insert_password_hstr();
    """)

    execute("""
    CREATE TRIGGER on_user_update
    AFTER UPDATE
    ON users
    FOR EACH ROW
    WHEN (OLD.password IS DISTINCT FROM NEW.password)
    EXECUTE PROCEDURE insert_password_hstr();
    """)
  end

  def down do
    execute("DROP TRIGGER IF EXISTS on_user_insert ON users;")
    execute("DROP TRIGGER IF EXISTS on_user_update ON users;")
    execute("DROP FUNCTION IF EXISTS insert_password_hstr();")
  end
end
