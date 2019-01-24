defmodule Mithril.Repo.Migrations.UpdateConnectionScopes do
  use Ecto.Migration

  def change do
    # ======== Update client types ===========
    execute("""
    UPDATE client_types
    SET scope = replace(scope, 'client:read ', '')
    WHERE name IN ('MSP', 'PHARMACY', 'MIS');
    """)

    execute("""
      UPDATE client_types
      SET scope = replace(scope, ' client:read', '')
      WHERE name IN ('MSP', 'PHARMACY', 'MIS');
    """)

    execute("""
      UPDATE client_types
      SET scope = replace(scope, ' connection:read connection:write connection:refresh_secret connection:delete', '')
      WHERE name IN ('MSP', 'PHARMACY', 'MIS');
    """)

    execute("""
      UPDATE client_types
      SET scope = trim(scope)||' client:read connection:read connection:write connection:refresh_secret connection:delete'
      WHERE name IN ('MSP', 'PHARMACY', 'MIS');
    """)

    # ======== Update roles ===========
    execute("""
      UPDATE roles
      SET scope = replace(scope, 'client:read ', '')
      WHERE name IN ('MIS USER', 'OWNER', 'PHARMACY_OWNER');
    """)

    execute("""
      UPDATE roles
      SET scope = replace(scope, ' client:read', '')
      WHERE name IN ('MIS USER', 'OWNER', 'PHARMACY_OWNER');
    """)

    execute("""
      UPDATE roles
      SET scope = replace(scope, ' connection:read connection:write connection:refresh_secret connection:delete', '')
      WHERE name IN ('MIS USER', 'OWNER', 'PHARMACY_OWNER');
    """)

    execute("""
      UPDATE roles
      SET scope = trim(scope)||' client:read connection:read connection:write connection:refresh_secret connection:delete'
      WHERE name IN ('MIS USER', 'OWNER', 'PHARMACY_OWNER');
    """)

    # ======== Update broker scopes ===========
    execute("""
      UPDATE clients c
        SET priv_settings = jsonb_set(priv_settings, '{broker_scope}', to_json(replace(priv_settings ->> 'broker_scope', 'client:read ', ''))::jsonb)
      WHERE c.client_type_id = (SELECT client_types.id
                    FROM client_types WHERE client_types.name = 'MIS')
      AND priv_settings ->> 'broker_scope' IS NOT NULL ;
    """)

    execute("""
      UPDATE clients c
        SET priv_settings = jsonb_set(priv_settings, '{broker_scope}', to_json(replace(priv_settings ->> 'broker_scope', ' client:read', ''))::jsonb)
      WHERE c.client_type_id = (SELECT client_types.id
                    FROM client_types WHERE client_types.name = 'MIS');
    """)

    execute("""
      UPDATE clients c
        SET priv_settings = jsonb_set(priv_settings, '{broker_scope}', to_json(replace(priv_settings ->> 'broker_scope', ' connection:read connection:write connection:refresh_secret connection:delete', ''))::jsonb)
      WHERE c.client_type_id = (SELECT client_types.id
                    FROM client_types WHERE client_types.name = 'MIS');
    """)

    execute("""
      UPDATE clients c
        SET priv_settings = jsonb_set(priv_settings, '{broker_scope}', to_json(replace(priv_settings ->> 'broker_scope', 'connection:read connection:write connection:refresh_secret connection:delete', ''))::jsonb)
      WHERE c.client_type_id = (SELECT client_types.id
                    FROM client_types WHERE client_types.name = 'MIS');
    """)

    execute("""
      UPDATE clients c
        SET priv_settings = jsonb_set(priv_settings, '{broker_scope}', to_json(trim(priv_settings ->> 'broker_scope') || ' client:read connection:read connection:write connection:refresh_secret connection:delete')::jsonb)
      WHERE c.client_type_id = (SELECT client_types.id
                    FROM client_types WHERE client_types.name = 'MIS');
    """)

    # ======== Update MIS tokens ===========
    execute("""
      UPDATE tokens t
        SET details = jsonb_set(details, '{scope}', to_json(replace(details ->> 'scope', 'client:read ', ''))::jsonb)
      WHERE (t.details ->> 'client_id')::uuid IN (
        SELECT id
        FROM clients c
        WHERE c.client_type_id IN (SELECT id FROM client_types WHERE client_types.name = 'MIS')
      )
      AND t.details ->> 'scope' IS NOT NULL ;
    """)

    execute("""
      UPDATE tokens t
        SET details = jsonb_set(details, '{scope}', to_json(replace(details ->> 'scope', ' client:read', ''))::jsonb)
      WHERE (t.details ->> 'client_id')::uuid IN (
        SELECT id
        FROM clients c
        WHERE c.client_type_id IN (SELECT id FROM client_types WHERE client_types.name = 'MIS')
      )
      AND t.details ->> 'scope' IS NOT NULL ;
    """)

    execute("""
      UPDATE tokens t
        SET details = jsonb_set(details, '{scope}', to_json(replace(details ->> 'scope', ' connection:read connection:write connection:refresh_secret connection:delete', ''))::jsonb)
      WHERE (t.details ->> 'client_id')::uuid IN (
        SELECT id
        FROM clients c
        WHERE c.client_type_id IN (SELECT id FROM client_types WHERE client_types.name = 'MIS')
      )
      AND t.details ->> 'scope' IS NOT NULL ;
    """)

    execute("""
      UPDATE tokens t
        SET details = jsonb_set(details, '{scope}', to_json(replace(details ->> 'scope', 'connection:read connection:write connection:refresh_secret connection:delete', ''))::jsonb)
      WHERE (t.details ->> 'client_id')::uuid IN (
        SELECT id
        FROM clients c
        WHERE c.client_type_id IN (SELECT id FROM client_types WHERE client_types.name = 'MIS')
      )
      AND t.details ->> 'scope' IS NOT NULL ;
    """)

    execute("""
      UPDATE tokens t
        SET details = jsonb_set(details, '{scope}', to_json(trim(details ->> 'scope') || ' client:read connection:read connection:write connection:refresh_secret connection:delete')::jsonb)
      WHERE (t.details ->> 'client_id')::uuid IN (
        SELECT id
        FROM clients c
        WHERE c.client_type_id IN (SELECT id FROM client_types WHERE client_types.name = 'MIS')
      )
      AND t.details ->> 'scope' IS NOT NULL ;
    """)
  end
end
