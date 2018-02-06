defmodule MicroservicesHelper do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      use Plug.Router

      plug(:match)
      plug(:dispatch)
    end
  end
end
