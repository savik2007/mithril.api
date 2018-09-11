defmodule Mithril.Authorization.BrokerScope do
  alias Mithril.Clients
  alias Mithril.Clients.Client
  alias Mithril.Clients.Connection
  alias Mithril.Error
  alias Mithril.TokenAPI.Token

  @direct Client.access_type(:direct)
  @broker Client.access_type(:broker)

  def put_broker_scope_into_token_details(%Token{} = token, %Client{} = client, api_key) do
    case Map.get(client.priv_settings, "access_type") do
      nil ->
        Error.access_denied("Client settings must contain access_type.")

      # Clients such as NHS Admin, MIS
      @direct ->
        {:ok, token}

      # Clients such as MSP, PHARMACY
      @broker ->
        with :ok <- validate_api_key(api_key),
             {:ok, client} <- fetch_client_by_secret(api_key),
             {:ok, broker_scope} <- fetch_broker_scope(client) do
          put_broker_scope(token, broker_scope)
        end
    end
  end

  defp validate_api_key(api_key) when is_binary(api_key), do: :ok
  defp validate_api_key(_), do: Error.invalid_request("API-KEY header required.")

  defp fetch_client_by_secret(api_key) do
    case Clients.get_connection_with_client_by(secret: api_key) do
      %Connection{client: client} -> {:ok, client}
      _ -> Error.invalid_request("API-KEY header is invalid.")
    end
  end

  defp fetch_broker_scope(%Client{priv_settings: %{"broker_scope" => broker_scope}}), do: {:ok, broker_scope}
  defp fetch_broker_scope(_), do: Error.invalid_request("Incorrect broker settings.")

  defp put_broker_scope(token, broker_scope) do
    details = Map.put(token.details, "broker_scope", broker_scope)
    {:ok, Map.put(token, :details, details)}
  end
end
