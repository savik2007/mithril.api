defmodule Mithril.Authorization.BrokerScope do
  alias Mithril.ClientAPI
  alias Mithril.ClientAPI.Client
  alias Mithril.Error
  alias Mithril.TokenAPI.Token

  @direct ClientAPI.access_type(:direct)
  @broker ClientAPI.access_type(:broker)

  def put_broker_scope_into_token_details(%Token{} = token, %Client{} = client, api_key) do
    case Map.get(client.priv_settings, "access_type") do
      nil ->
        Error.access_denied("Client settings must contain access_type.")

      # Clients such as NHS Admin, MIS
      @direct ->
        {:ok, token}

      # Clients such as MSP, PHARMACY
      @broker ->
        api_key
        |> validate_api_key()
        |> fetch_client_by_secret()
        |> fetch_broker_scope()
        |> put_broker_scope_into_token(token)
    end
  end

  defp validate_api_key(api_key) when is_binary(api_key), do: api_key
  defp validate_api_key(_), do: Error.invalid_request("API-KEY header required.")

  defp fetch_client_by_secret({:error, _} = err), do: err

  defp fetch_client_by_secret(api_key) do
    case ClientAPI.get_client_by(secret: api_key) do
      %Client{} = client -> client
      _ -> Error.invalid_request("API-KEY header is invalid.")
    end
  end

  defp fetch_broker_scope({:error, _} = err), do: err
  defp fetch_broker_scope(%Client{priv_settings: %{"broker_scope" => broker_scope}}), do: broker_scope
  defp fetch_broker_scope(_), do: Error.invalid_request("Incorrect broker settings.")

  defp put_broker_scope_into_token({:error, _} = err, _token), do: err

  defp put_broker_scope_into_token(broker_scope, token) do
    details = Map.put(token.details, "broker_scope", broker_scope)
    {:ok, Map.put(token, :details, details)}
  end
end
