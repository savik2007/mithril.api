defmodule Mithril.ReCAPTCHA do
  @moduledoc """
  Google reCAPTCHA validator
  """

  @behaviour Mithril.API.ReCAPTCHABehaviour
  @http_client Application.get_env(:mithril_api, :api_resolvers)[:recaptcha]

  use Confex, otp_app: :mithril_api

  def verify(response, remote_ip \\ nil) do
    body = %{
      secret: config()[:secret],
      response: response,
      remote_ip: remote_ip
    }

    body
    |> URI.encode_query()
    |> @http_client.verify_token()
    |> case do
      {:ok, %{"success" => true}} ->
        :ok

      {:ok, %{"error-codes" => errors}} ->
        {:error, {:forbidden, %{message: "Invalid CAPTCHA token. Errors: #{traverse_errors(errors)}"}}}

      _ ->
        {:error, {:forbidden, %{message: "Invalid CAPTCHA token"}}}
    end
  end

  def verify_token(body) do
    url = config()[:url]

    headers = [
      {"Content-type", "application/x-www-form-urlencoded"}
    ]

    result =
      with {:ok, response} <- HTTPoison.post(url, body, headers),
           {:ok, data} <- Jason.decode(response.body) do
        {:ok, data}
      end

    case result do
      {:ok, data} -> {:ok, data}
      {:error, :invalid} -> {:error, [:invalid_api_response]}
      {:error, {:invalid, _reason}} -> {:error, [:invalid_api_response]}
      {:error, %{reason: reason}} -> {:error, [reason]}
    end
  end

  defp traverse_errors(errors) when is_list(errors), do: Enum.join(errors, ", ")
  defp traverse_errors(errors), do: inspect(errors)
end
