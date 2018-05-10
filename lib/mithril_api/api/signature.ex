defmodule Mithril.API.Signature do
  @moduledoc """
  Signature validator and data mapper
  """
  require Logger

  use HTTPoison.Base
  use Confex, otp_app: :mithril_api
  use Mithril.API.Helpers.MicroserviceBase

  @behaviour Mithril.API.SignatureBehaviour

  def decode_and_validate(signed_content, signed_content_encoding, attrs \\ %{}, headers \\ []) do
    if config()[:enabled] do
      params = %{
        "signed_content" => signed_content,
        "signed_content_encoding" => signed_content_encoding
      }

      result = post!("/digital_signatures", Poison.encode!(params), headers, config()[:hackney_options])

      {_, response} = result

      Logger.info(fn ->
        Poison.encode!(%{
          "log_type" => "microservice_response",
          "microservice" => "digital-signature",
          "result" => response,
          "request_id" => Logger.metadata()[:request_id]
        })
      end)

      result
    else
      data = Base.decode64(signed_content)

      case data do
        :error ->
          data_is_invalid_resp()

        {:ok, data} ->
          case Poison.decode(data) do
            {:ok, data} -> data_is_valid_resp(data, attrs)
            _ -> data_is_invalid_resp()
          end
      end
    end
  end

  defp data_is_valid_resp(data, attrs) do
    data =
      %{
        "content" => data,
        "signatures" => [
          %{
            "is_valid" => true,
            "signer" => %{
              "edrpou" => Map.get(attrs, "edrpou"),
              "drfo" => Map.get(attrs, "drfo")
            },
            "validation_error_message" => ""
          }
        ]
      }
      |> wrap_response(200)
      |> Poison.encode!()

    ResponseDecoder.check_response(%HTTPoison.Response{body: data, status_code: 200})
  end

  defp data_is_invalid_resp do
    data =
      %{
        "error" => %{
          "invalid" => [
            %{
              "entry" => "$.signed_content",
              "entry_type" => "json_data_property",
              "rules" => [
                %{
                  "description" => "Not a base64 string",
                  "params" => [],
                  "rule" => "invalid"
                }
              ]
            }
          ],
          "message" =>
            "Validation failed. You can find validators description at our API Manifest:" <>
              " http://docs.apimanifest.apiary.io/#introduction/interacting-with-api/errors.",
          "type" => "validation_failed"
        },
        "meta" => %{
          "code" => 422,
          "request_id" => "2kmaguf9ec791885t40008s2",
          "type" => "object",
          "url" => "http://www.example.com/digital_signatures"
        }
      }
      |> Poison.encode!()

    ResponseDecoder.check_response(%HTTPoison.Response{body: data, status_code: 422})
  end

  defp wrap_response(data, code) do
    %{
      "meta" => %{
        "code" => code,
        "type" => "list"
      },
      "data" => data
    }
  end
end
