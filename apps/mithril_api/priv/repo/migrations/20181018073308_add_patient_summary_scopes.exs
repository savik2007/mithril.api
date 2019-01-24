defmodule Mithril.Repo.Migrations.AddPatientSummaryScopes do
  use Ecto.Migration

  def change do
    # ======== Update client types ===========
    execute("""
    UPDATE client_types
    SET scope = trim(scope) || ' patient_summary:read'
    WHERE name IN ('MSP')
    AND scope NOT LIKE '%patient_summary:read%';
    """)

    # ======== Update roles ===========
    execute("""
    UPDATE roles
    SET scope = trim(scope) || ' patient_summary:read'
    WHERE name IN ('DOCTOR')
    AND scope NOT LIKE '%patient_summary:read%';
    """)

    # ======== Update broker scopes ===========
    execute("""
    UPDATE clients c
        SET priv_settings = jsonb_set(priv_settings, '{broker_scope}', to_json(trim(priv_settings ->> 'broker_scope') || ' patient_summary:read')::jsonb)
      WHERE c.client_type_id = (SELECT client_types.id
                    FROM client_types WHERE client_types.name = 'MIS')
        AND c.priv_settings ->> 'broker_scope' NOT LIKE '%patient_summary:read%';
    """)
  end
end
