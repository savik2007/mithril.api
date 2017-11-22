defmodule Mithril.Web.AuthenticationFactorController do
  @moduledoc false

  use Mithril.Web, :controller

  alias Mithril.Authentication
  alias Mithril.Authentication.Factor
  alias Scrivener.Page

  action_fallback Mithril.Web.FallbackController

  def index(conn, params) do
    with %Page{} = paging <- Authentication.list_factors(params) do
      render(conn, "index.json", factors: paging.entries, paging: paging)
    end
  end

  def show(conn, %{"id" => id, "user_id" => user_id}) do
    factor = Authentication.get_factor_by!([id: id, user_id: user_id])
    render(conn, "show.json", factor: factor)
  end

  def create(conn, attrs) do
    with {:ok, %Factor{} = factor} <- Authentication.create_factor(attrs) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", user_authentication_factor_path(conn, :show, factor.user_id, factor))
      |> render("show.json", factor: factor)
    end
  end

  def disable(conn, %{"id" => id, "user_id" => user_id}) do
    with %Factor{is_active: true} = factor <- Authentication.get_factor_by!([id: id, user_id: user_id]),
         {:ok, %Factor{} = factor} <- Authentication.update_factor(factor, %{"is_active" => false}) do
      render(conn, "show.json", factor: factor)
    else
      %Factor{is_active: false} -> {:error, {:conflict, "user authentication factor already disabled"}}
      err -> err
    end
  end

  def enable(conn, %{"id" => id, "user_id" => user_id}) do
    with %Factor{is_active: false} = factor <- Authentication.get_factor_by!([id: id, user_id: user_id]),
         {:ok, %Factor{} = factor} <- Authentication.update_factor(factor, %{"is_active" => true}) do
      render(conn, "show.json", factor: factor)
    else
      %Factor{is_active: true} -> {:error, {:conflict, "user authentication factor already enabled"}}
      err -> err
    end
  end

  def reset(conn, %{"id" => id, "user_id" => user_id}) do
    factor = Authentication.get_factor_by!([id: id, user_id: user_id, is_active: true])

    with {:ok, %Factor{} = factor} <- Authentication.update_factor(factor, %{"factor" => nil}) do
      render(conn, "show.json", factor: factor)
    end
  end
end
