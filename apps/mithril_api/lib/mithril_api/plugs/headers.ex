defmodule Mithril.Plugs.Headers do
  @moduledoc """
  Plug.Conn helpers
  """

  @header_consumer_id "x-consumer-id"
  @header_api_key "api-key"

  import Plug.Conn, only: [put_status: 2, get_req_header: 2, halt: 1]
  import Phoenix.Controller, only: [render: 3, put_view: 2]

  def put_user_id_header(%Plug.Conn{params: params, req_headers: headers} = conn, _) do
    %{conn | params: Map.merge(params, %{"user_id" => get_consumer_id(headers)})}
  end

  def put_api_key_header(%Plug.Conn{params: params, req_headers: headers} = conn, _) do
    %{conn | params: Map.merge(params, %{"api_key" => get_api_key(headers)})}
  end

  def header_required(%Plug.Conn{} = conn, header) do
    case get_req_header(conn, header) do
      [] ->
        conn
        |> put_status(:unauthorized)
        |> put_view(EView.Views.Error)
        |> render(:"401", %{
          message: "Missing header #{header}",
          invalid: [
            %{
              entry_type: :header,
              entry: header
            }
          ]
        })
        |> halt()

      _ ->
        conn
    end
  end

  def get_consumer_id(headers) do
    get_header(headers, @header_consumer_id)
  end

  def get_api_key(headers) do
    get_header(headers, @header_api_key)
  end

  def get_header(headers, header) when is_list(headers) do
    Enum.reduce_while(headers, nil, fn {k, v}, acc ->
      if String.downcase(k) == String.downcase(header) do
        {:halt, v}
      else
        {:cont, acc}
      end
    end)
  end
end
