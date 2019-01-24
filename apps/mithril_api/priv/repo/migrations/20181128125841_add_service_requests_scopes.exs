defmodule Mithril.Repo.Migrations.AddServiceRequestsScopes do
  use Ecto.Migration

  def change do
    # ======== Update client types ===========
    execute("""
    DO
    $$DECLARE r record;
    BEGIN
        FOR r IN SELECT unnest(ARRAY['service_request:write', 'service_request:read', 'service_request:use']) as scope
    LOOP
        EXECUTE 'UPDATE client_types SET scope = lower(replace(upper(scope), upper($1), '''')) WHERE name = ''MSP'' and upper(scope) ~ upper($2);' USING r.scope, r.scope;
    END LOOP;
    END$$;
    """)

    execute("""
    UPDATE client_types
    SET scope = trim(regexp_replace(scope, '\s+', ' ', 'g')) || ' service_request:write service_request:read service_request:use'
    WHERE name IN ('MSP');
    """)

    # ======== Update roles ===========
    execute("""
    DO
    $$DECLARE r record;
    BEGIN
        FOR r IN SELECT unnest(ARRAY['service_request:write', 'service_request:read', 'service_request:use']) as scope
    LOOP
        EXECUTE 'UPDATE roles SET scope = lower(replace(upper(scope), upper($1), '''')) WHERE name IN (''DOCTOR'', ''OWNER'', ''ADMIN'') AND upper(scope) ~ upper($2);' USING r.scope, r.scope;
    END LOOP;
    END$$;
    """)

    execute("""
    UPDATE roles
    SET scope = trim(regexp_replace(scope, '\s+', ' ', 'g')) || ' service_request:write service_request:read service_request:use'
    WHERE name IN ('DOCTOR');
    """)

    execute("""
    UPDATE roles
    SET scope = trim(regexp_replace(scope, '\s+', ' ', 'g')) || ' service_request:read service_request:use'
    WHERE name IN ('ADMIN');
    """)

    execute("""
    UPDATE roles
    SET scope = trim(regexp_replace(scope, '\s+', ' ', 'g')) || ' service_request:read'
    WHERE name IN ('OWNER');
    """)
  end
end
