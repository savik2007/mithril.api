defmodule Mithril.Repo.Migrations.AddServiceRequestsBrokerScopes do
  use Ecto.Migration

  def change do
    # ======== Update broker scopes ===========
    execute("""
    DO $$DECLARE r record;
    BEGIN
      FOR r IN SELECT unnest(ARRAY['service_request:write', 'service_request:read', 'service_request:use']) as scope
    LOOP
      EXECUTE 'UPDATE clients SET priv_settings = jsonb_set(priv_settings, ''{broker_scope}'', to_json(lower(replace(upper(trim(priv_settings ->> ''broker_scope'')), upper($1), '''')))::jsonb) WHERE upper(priv_settings::text) ~ upper($2);' USING r.scope, r.scope;
    END LOOP;
    END$$;
    """)

    execute("""
    UPDATE clients c
    SET priv_settings = jsonb_set(priv_settings, '{broker_scope}', to_json(trim(priv_settings ->> 'broker_scope') || ' service_request:write service_request:read service_request:use')::jsonb)
    WHERE c.client_type_id = (SELECT client_types.id
    FROM client_types WHERE client_types.name = 'MIS')
    AND c.priv_settings ->> 'broker_scope' NOT LIKE '%service_request:write service_request:read service_request:use%';
    """)
  end
end
