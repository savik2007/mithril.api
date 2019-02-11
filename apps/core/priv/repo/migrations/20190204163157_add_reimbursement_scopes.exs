defmodule Core.Repo.Migrations.AddReimbursementScopes do
  use Ecto.Migration

  def change do
    # ======== Update client types ===========
    execute("""
    DO
    $$DECLARE r record;
    BEGIN
        FOR r IN SELECT unnest(ARRAY['contract_request:create', 'contract_request:read', 'contract_request:terminate', 'contract_request:approve', 'contract_request:sign', 'contract:read', 'contract:write']) as scope
    LOOP
        EXECUTE 'UPDATE client_types SET scope = lower(replace(upper(scope), upper($1), '''')) WHERE name = ''PHARMACY'' and upper(scope) ~ upper($2);' USING r.scope, r.scope;
    END LOOP;
    END$$;
    """)

    execute("""
    UPDATE client_types
    SET scope = trim(regexp_replace(scope, '\s+', ' ', 'g')) || ' contract_request:create contract_request:read contract_request:terminate contract_request:approve contract_request:sign contract:read contract:write'
    WHERE name IN ('PHARMACY');
    """)

    # ======== Update roles ===========
    execute("""
    DO
    $$DECLARE r record;
    BEGIN
        FOR r IN SELECT unnest(ARRAY['drugs:read', 'medication_dispense:read', 'medication_request:details', 'medication_request:read', 'medication_request:reject', 'medication_request:resend', 'medication_request_request:read', 'medication_request_request:reject', 'medication_request_request:sign', 'medication_request_request:write']) as scope
    LOOP
        EXECUTE 'UPDATE roles SET scope = lower(replace(upper(scope), upper($1), '''')) WHERE name IN (''DOCTOR'') AND upper(scope) ~ upper($2);' USING r.scope, r.scope;
    END LOOP;
    END$$;
    """)

    execute("""
    DO
    $$DECLARE r record;
    BEGIN
        FOR r IN SELECT unnest(ARRAY['drugs:read', 'medication_dispense:read', 'medication_request:details', 'medication_request:read', 'medication_request:reject', 'medication_request:resend', 'medication_request_request:read', 'medication_request_request:reject', 'medication_request_request:sign', 'medication_request_request:write']) as scope
    LOOP
        EXECUTE 'UPDATE roles SET scope = lower(replace(upper(scope), upper($1), '''')) WHERE name IN (''DOCTOR'') AND upper(scope) ~ upper($2);' USING r.scope, r.scope;
    END LOOP;
    END$$;
    """)

    execute("""
    UPDATE roles
    SET scope = trim(regexp_replace(scope, '\s+', ' ', 'g')) || ' drugs:read medication_dispense:read medication_request:details medication_request:read medication_request:reject medication_request:resend medication_request_request:read medication_request_request:reject medication_request_request:sign medication_request_request:write'
    WHERE name IN ('DOCTOR');
    """)

    execute("""
    DO
    $$DECLARE r record;
    BEGIN
        FOR r IN SELECT unnest(ARRAY['contract_request:create', 'contract_request:read', 'contract_request:terminate', 'contract_request:approve', 'contract_request:sign', 'contract:read', 'contract:write']) as scope
    LOOP
        EXECUTE 'UPDATE roles SET scope = lower(replace(upper(scope), upper($1), '''')) WHERE name IN (''PHARMACY_OWNER'') AND upper(scope) ~ upper($2);' USING r.scope, r.scope;
    END LOOP;
    END$$;
    """)

    execute("""
    UPDATE roles
    SET scope = trim(regexp_replace(scope, '\s+', ' ', 'g')) || ' contract_request:create contract_request:read contract_request:terminate contract_request:approve contract_request:sign contract:read contract:write'
    WHERE name IN ('PHARMACY_OWNER');
    """)

    execute("""
    UPDATE clients c
    SET priv_settings = jsonb_set(priv_settings, '{broker_scope}', to_json(trim(priv_settings ->> 'broker_scope') || ' drugs:read medication_dispense:read medication_request:details medication_request:read medication_request:reject medication_request:resend medication_request_request:read medication_request_request:reject medication_request_request:sign medication_request_request:write medication_dispense:write medication_dispense:process medication_dispense:reject')::jsonb)
    WHERE c.client_type_id = (SELECT client_types.id
    FROM client_types WHERE client_types.name = 'MIS')
    AND c.priv_settings ->> 'broker_scope' NOT LIKE '%drugs:read medication_dispense:read medication_request:details medication_request:read medication_request:reject medication_request:resend medication_request_request:read medication_request_request:reject medication_request_request:sign medication_request_request:write medication_dispense:write medication_dispense:process medication_dispense:reject%';
    """)
  end
end
