defmodule Core.Test.Helpers do
  def cleanup_fixture_roles do
    Core.Repo.delete_all(Core.RoleAPI.Role)
  end

  def cleanup_fixture_client_type do
    Core.Repo.delete_all(Core.ClientTypeAPI.ClientType)
  end
end
