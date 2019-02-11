defmodule Core.API.MPI do
  @moduledoc false

  use HTTPoison.Base
  use Confex, otp_app: :core
  use Core.API.Helpers.MicroserviceBase

  @behaviour Core.API.MPIBehaviour

  def person(id, headers \\ []) do
    get!("/persons/#{id}", headers)
  end
end
