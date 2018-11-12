defmodule Mithril.Repo.Migrations.UpdateConnectionsScope do
  use Ecto.Migration

  def change do
  end
end

defmodule Mithril.Repo.Migrations.UpdateConnectionScopes do
  use Ecto.Migration

  def change do
    # ======== Update broker scopes ===========
    execute("""
    DO $$DECLARE r record;
    BEGIN
      FOR r IN SELECT unnest(ARRAY['related_legal_entities:read']) as scope
    LOOP
      EXECUTE 'UPDATE clients SET priv_settings = jsonb_set(priv_settings, ''{broker_scope}'', to_json(lower(replace(upper(trim(priv_settings ->> ''broker_scope'')), upper($1), '''')))::jsonb) WHERE upper(priv_settings::text) ~ upper($2);' USING r.scope, r.scope;
    END LOOP;
    END$$;
    """)

    execute("""
    UPDATE clients c
    SET priv_settings = jsonb_set(priv_settings, '{broker_scope}', to_json(trim(priv_settings ->> 'broker_scope') || ' related_legal_entities:read')::jsonb)
    WHERE c.client_type_id = (SELECT client_types.id
    FROM client_types WHERE client_types.name = 'MIS')
    AND c.priv_settings ->> 'broker_scope' NOT LIKE '%related_legal_entities:read%';
    """)

    # ======== Update roles ===========
    # ------------------NHS ADMIN--------
    execute("""
    DO $$DECLARE r record;
    BEGIN
      FOR r IN SELECT unnest(ARRAY['legal_entity:merge', 'related_legal_entities:read', 'legal_entity_merge_job:read']) as scope
    LOOP
      EXECUTE 'UPDATE roles SET scope = lower(replace(upper(scope), upper($1), '''')) WHERE upper(scope) ~ upper($2);' USING r.scope, r.scope;
    END LOOP;
    END$$;
    """)

    execute("""
    UPDATE roles
    SET scope = trim(scope) || ' legal_entity:merge related_legal_entities:read legal_entity_merge_job:read'
    WHERE name IN ('NHS ADMIN')
    AND scope NOT LIKE '%legal_entity:merge related_legal_entities:read legal_entity_merge_job:read%';
    """)

    # ---------------------OWNER---------
    execute("""
    DO $$DECLARE r record;
    BEGIN
      FOR r IN SELECT unnest(ARRAY['related_legal_entities:read']) as scope
    LOOP
      EXECUTE 'UPDATE roles SET scope = lower(replace(upper(scope), upper($1), '''')) WHERE upper(scope) ~ upper($2);' USING r.scope, r.scope;
    END LOOP;
    END$$;
    """)

    execute("""
    UPDATE roles
    SET scope = trim(scope) || ' related_legal_entities:read'
    WHERE name IN ('OWNER')
    AND scope NOT LIKE '%related_legal_entities:read%';
    """)

    # ======== Update client types ===========

    # ------------------NHS ADMIN--------
    execute("""
    DO $$DECLARE r record;
    BEGIN
      FOR r IN SELECT unnest(ARRAY['legal_entity:merge', 'related_legal_entities:read', 'legal_entity_merge_job:read']) as scope
    LOOP
      EXECUTE 'UPDATE client_types SET scope = lower(replace(upper(scope), upper($1), '''')) WHERE upper(scope) ~ upper($2);' USING r.scope, r.scope;
    END LOOP;
    END$$;
    """)

    execute("""
    UPDATE client_types
    SET scope = trim(scope) || 'legal_entity:merge related_legal_entities:read legal_entity_merge_job:read'
    WHERE name IN ('NHS ADMIN', 'NHS')
    AND scope NOT LIKE '%legal_entity:merge related_legal_entities:read legal_entity_merge_job:read%';
    """)

    # ---------------------OWNER---------
    execute("""
    DO $$DECLARE r record;
    BEGIN
      FOR r IN SELECT unnest(ARRAY['related_legal_entities:read']) as scope
    LOOP
      EXECUTE 'UPDATE client_types SET scope = lower(replace(upper(scope), upper($1), '''')) WHERE upper(scope) ~ upper($2);' USING r.scope, r.scope;
    END LOOP;
    END$$;
    """)

    execute("""
    UPDATE client_types
    SET scope = trim(scope) || ' related_legal_entities:read'
    WHERE name IN ('MSP')
    AND scope NOT LIKE '%related_legal_entities:read%';
    """)

    execute("""
    DO $$DECLARE r NUMERIC;
    BEGIN
      SELECT count(1)
      INTO r
        FROM client_types
        WHERE name = 'MSP_LIMITED';
        IF r = 0
    THEN
      INSERT INTO client_types VALUES (
      '3770c4b3-05cd-42d9-8e15-233b193aee86', 'MSP_LIMITED',
      'capitation_report:read declaration:read declaration_request:read division:details division:read drugs:read employee:details employee:read employee_request:read legal_entity:read medication_dispense:read medication_request:details medication_request:read medication_request_request:read otp:read person:read reimbursement_report:read secret:refresh contract_request:read contract:read encounter:read episode:read job:read client:read connection:read condition:read observation:read immunization:read allergy_intolerance:read related_legal_entities:read',
      now(), now()
      );
    END IF;
    END$$;
    """)
  end
end
