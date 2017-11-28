defmodule Mithril.Authorization.GrantType.RefreshToken do
  @moduledoc false

  alias Mithril.Error

  def authorize(%{"client_id" => client_id, "client_secret" => client_secret, "refresh_token" => token})
      when not (is_nil(client_id) or is_nil(client_secret) or is_nil(token))
  do
    {client_id, client_secret, token}
    |> load_client
    |> load_token
    |> validate_client_match
    |> validate_token_expiration
    |> validate_app_authorization
    |> create_access_token
  end
  def authorize(_) do
    message = "Request must include at least client_id, client_secret and refresh_token parameters."
    Error.invalid_request(message)
  end

  defp load_client({client_id, client_secret, token}) do
    case Mithril.ClientAPI.get_client_by(id: client_id, secret: client_secret) do
      nil ->
        Error.invalid_client("Invalid client id or secret.")
      client ->
        {:ok, client, token}
    end
  end

  defp load_token({:error, _} = err), do: err
  defp load_token({:ok, client, value}) do
    case Mithril.TokenAPI.get_token_by(value: value, name: "refresh_token") do
      nil ->
        Error.invalid_grant("Token not found.")
      token ->
        {:ok, client, token}
    end
  end

  defp validate_client_match({:error, _} = err), do: err
  defp validate_client_match({:ok, client, token}) do
    case token.details["client_id"] == client.id do
      true ->
        {:ok, client, token}
      _ ->
        Error.invalid_grant("Token not found or expired.")
    end
  end

  defp validate_token_expiration({:error, _} = err), do: err
  defp validate_token_expiration({:ok, client, token}) do
    if Mithril.TokenAPI.expired?(token) do
      Error.invalid_grant("Token expired.")
    else
      {:ok, client, token}
    end
  end

  defp validate_app_authorization({:error, _} = err), do: err
  defp validate_app_authorization({:ok, client, token}) do
    case Mithril.AppAPI.approval(token.user_id, token.details["client_id"]) do
      nil ->
        Error.access_denied("Resource owner revoked access for the client.")
      app ->
        {:ok, client, token, app}
    end
  end

  defp create_access_token({:error, _} = err), do: err
  defp create_access_token({:ok, client, token, app}) do
    Mithril.TokenAPI.create_access_token(%{
      user_id: token.user_id,
      details: %{
        grant_type: "refresh_token",
        client_id: client.id,
        scope: app.scope
      }
    })
  end
end
