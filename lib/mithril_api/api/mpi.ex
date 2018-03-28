defmodule Mithril.API.MPI do
  use HTTPoison.Base
  use Confex, otp_app: :mithril_api
  use Mithril.API.Helpers.MicroserviceBase

  @behaviour Mithril.API.MPIBehaviour

  def person(id, headers \\ []) do
    get!("/persons/#{id}", headers)
  end
end
