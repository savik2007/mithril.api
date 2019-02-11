defmodule Core.Repo.Migrations.SetClientBrokerScopes do
  use Ecto.Migration

  def change do
    sql = """
      UPDATE clients
      SET priv_settings = '{"access_type": "DIRECT", "broker_scope": "employee:deactivate medication_request_request:reject legal_entity:read declaration_request:sign medication_request:details division:activate employee:details division:deactivate otp:write declaration_request:read employee_request:read employee_request:reject employee_request:write division:read medication_request:resend employee:write declaration_request:write medical_program:deactivate division:details client:read division:write medical_program:read medication_dispense:reject declaration:read medication_request_request:sign drugs:read medication_dispense:process secret:refresh medical_program:write otp:read medication_request_request:write medication_request_request:read medication_request:read medication_dispense:read person:read medication_dispense:write declaration_request:approve employee_request:approve medication_request:reject declaration_request:reject reimbursement_report:read employee:read"}'
      FROM client_types
      WHERE client_types.name = 'MIS'
      AND clients.client_type_id = client_types.id;
    """

    execute(sql)
  end
end
