if Code.ensure_loaded?(Plug) do
  defmodule Plugination do
    @moduledoc false
    use Phoenix.Controller

    import Plug.Conn

    alias Ecto.Changeset
    alias Plug.Conn

    def init(opts), do: opts

    def call(%Conn{params: params} = conn, opts) do
      validator = fetch_validator!(opts)

      case validator.changeset(params) do
        %Changeset{valid?: true} = changeset ->
          assign(conn, :validated_params, changeset)

        %Changeset{valid?: false} = changeset ->
          err_handler = fetch_error_handler!(opts)

          conn
          |> err_handler.call(changeset)
          |> halt()

        result ->
          raise("Expected validator #{validator}.changeset/1 return %Ecto.Changeset{}, #{inspect(result)} given")
      end
    end

    defp fetch_validator!(opts), do: fetch!(opts, :validator)
    defp fetch_error_handler!(opts), do: fetch!(opts, :error_handler)

    defp fetch!(opts, key) do
      case Keyword.get(opts, key) do
        nil -> raise_error(key)
        handler -> handler
      end
    end

    defp raise_error(key), do: raise("Config `#{key}` is missing for #{__MODULE__}")
  end
end
