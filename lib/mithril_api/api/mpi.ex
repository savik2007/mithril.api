defmodule Mithril.API.MPI do
  use HTTPoison.Base
  use Confex, otp_app: :mithril_api
  use Mithril.API.Helpers.MicroserviceBase

  @behaviour Mithril.API.MPIBehaviour

  def search(params, headers) do
    get!("/persons", headers, params: params)
  end
end
