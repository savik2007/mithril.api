defmodule Core.Utils.RedirectUriChecker do
  @moduledoc false

  def generate_redirect_uri_regexp(redirect_uri) do
    ~r/\/$/
    |> Regex.replace(redirect_uri, "")
    |> Regex.escape()
    |> Kernel.<>("((\/.*)|(\\?.*))?$")
    |> Regex.compile!()
  end
end
