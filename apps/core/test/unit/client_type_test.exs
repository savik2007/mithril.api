defmodule Core.RoleAPI.ClientTypeTest do
  use ExUnit.Case

  test "MIS client type" do
    role = %Core.RoleAPI.Role{
      name: "MIS",
      scope: "
        legal_entity:write
        legal_entity:read
        employee_request:read
      "
    }

    assert String.contains?(role.scope, "legal_entity:write")
    assert String.contains?(role.scope, "legal_entity:read")
    assert String.contains?(role.scope, "employee_request:read")
  end
end
