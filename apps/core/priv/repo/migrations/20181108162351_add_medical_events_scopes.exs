defmodule Core.Repo.Migrations.AddMedicalEventsScopes do
  use Ecto.Migration

  def change do
    # ======== Update client types ===========
    execute("""
    DO
    $$DECLARE r record;
    BEGIN
        FOR r IN SELECT unnest(ARRAY['encounter:write', 'encounter:read', 'episode:write', 'episode:read', 'job:read', 'condition:read', 'observation:read', 'immunization:read', 'allergy_intolerance:read', 'encounter:cancel']) as scope
    LOOP
        EXECUTE 'UPDATE client_types SET scope = lower(replace(upper(scope), upper($1), '''')) WHERE upper(scope) ~ upper($2);' USING r.scope, r.scope;
    END LOOP;
    END$$;
    """)

    execute("""
    UPDATE client_types
    SET scope = trim(scope) || ' encounter:write encounter:read episode:write episode:read job:read condition:read observation:read immunization:read allergy_intolerance:read encounter:cancel'
    WHERE name IN ('MSP')
    AND scope NOT LIKE '%encounter:write encounter:read episode:write episode:read job:read condition:read observation:read immunization:read allergy_intolerance:read encounter:cancel%';
    """)

    # ======== Update roles ===========
    execute("""
    DO
    $$DECLARE r record;
    BEGIN
        FOR r IN SELECT unnest(ARRAY['encounter:write', 'encounter:read', 'episode:write', 'episode:read', 'job:read', 'condition:read', 'observation:read', 'immunization:read', 'allergy_intolerance:read', 'encounter:cancel']) as scope
    LOOP
        EXECUTE 'UPDATE roles SET scope = lower(replace(upper(scope), upper($1), '''')) WHERE upper(scope) ~ upper($2);' USING r.scope, r.scope;
    END LOOP;
    END$$;
    """)

    execute("""
    UPDATE roles
    SET scope = trim(scope) || ' encounter:write encounter:read episode:write episode:read job:read condition:read observation:read immunization:read allergy_intolerance:read encounter:cancel'
    WHERE name IN ('DOCTOR')
    AND scope NOT LIKE '%encounter:write encounter:read episode:write episode:read job:read condition:read observation:read immunization:read allergy_intolerance:read encounter:cancel%';
    """)

    # ======== Update broker scopes ===========
    execute("""
    DO
    $$DECLARE r record;
    BEGIN
        FOR r IN SELECT unnest(ARRAY['encounter:write', 'encounter:read', 'episode:write', 'episode:read', 'job:read', 'condition:read', 'observation:read', 'immunization:read', 'allergy_intolerance:read', 'encounter:cancel']) as scope
    LOOP
        EXECUTE 'UPDATE clients SET priv_settings = jsonb_set(priv_settings, ''{broker_scope}'', to_json(lower(replace(upper(trim(priv_settings ->> ''broker_scope'')), upper($1), '''')))::jsonb) WHERE upper(priv_settings::text) ~ upper($2);' USING r.scope, r.scope;
    END LOOP;
    END$$;
    """)

    execute("""
    UPDATE clients c
        SET priv_settings = jsonb_set(priv_settings, '{broker_scope}', to_json(trim(priv_settings ->> 'broker_scope') || ' encounter:write encounter:read episode:write episode:read job:read condition:read observation:read immunization:read allergy_intolerance:read encounter:cancel')::jsonb)
      WHERE c.client_type_id = (SELECT client_types.id
                    FROM client_types WHERE client_types.name = 'MIS')
        AND c.priv_settings ->> 'broker_scope' NOT LIKE '%encounter:write encounter:read episode:write episode:read job:read condition:read observation:read immunization:read allergy_intolerance:read encounter:cancel%';
    """)
  end
end
