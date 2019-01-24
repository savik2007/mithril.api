defmodule Mithril.Test.Helpers do
  def cleanup_fixture_roles do
    Mithril.Repo.delete_all(Mithril.RoleAPI.Role)
  end

  def cleanup_fixture_client_type do
    Mithril.Repo.delete_all(Mithril.ClientTypeAPI.ClientType)
  end
end
