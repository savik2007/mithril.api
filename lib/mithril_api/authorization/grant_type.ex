defmodule Mithril.Authorization.GrantType do
  import Mithril.Authorization.Tokens, only: [next_step: 1]

  alias Mithril.TokenAPI.Token
  alias Mithril.ClientAPI.Client
  alias Mithril.ClientTypeAPI
  alias Mithril.ClientTypeAPI.ClientType

  @cabinet_client_type ClientType.client_type(:cabinet)
  @ehealth_cabinet_client_id "30074b6e-fbab-4dc1-9d37-88c21dab1847"

  def prepare_scope_by_client(%Client{id: @ehealth_cabinet_client_id}, _requested_scope) do
    case ClientTypeAPI.get_client_type_by(name: @cabinet_client_type) do
      %ClientType{scope: scope} -> {:ok, scope}
      _ -> {:error, {:internal_error, "EHealth ClientType was not set in DB"}}
    end
  end

  def prepare_scope_by_client(_, scope), do: {:ok, scope}

  def map_next_step(%Token{details: %{"client_id" => @ehealth_cabinet_client_id}}), do: next_step(:request_api)
  def map_next_step(%Token{}), do: next_step(:request_apps)
end
