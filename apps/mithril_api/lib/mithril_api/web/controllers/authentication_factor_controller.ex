defmodule Mithril.Web.AuthenticationFactorController do
  @moduledoc false

  use Mithril.Web, :controller

  alias Core.Authentication.Factor
  alias Core.Authentication.Factors
  alias Mithril.Web.AuthenticationFactorView
  alias Scrivener.Page

  action_fallback(Mithril.Web.FallbackController)

  def index(conn, params) do
    with %Page{} = paging <- Factors.list_factors(params) do
      conn
      |> put_view(AuthenticationFactorView)
      |> render("index.json", factors: paging.entries, paging: paging)
    end
  end

  def show(conn, %{"id" => id, "user_id" => user_id}) do
    factor = Factors.get_factor_by!(id: id, user_id: user_id)

    conn
    |> put_view(AuthenticationFactorView)
    |> render("show.json", factor: factor)
  end

  def create(conn, attrs) do
    with {:ok, %Factor{} = factor} <- Factors.create_factor(attrs) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", user_authentication_factor_path(conn, :show, factor.user_id, factor))
      |> put_view(AuthenticationFactorView)
      |> render("show.json", factor: factor)
    end
  end

  def disable(conn, %{"id" => id, "user_id" => user_id}) do
    with %Factor{is_active: true} = factor <- Factors.get_factor_by!(id: id, user_id: user_id),
         {:ok, %Factor{} = factor} <- Factors.update_factor(factor, %{"is_active" => false}) do
      conn
      |> put_view(AuthenticationFactorView)
      |> render("show.json", factor: factor)
    else
      %Factor{is_active: false} -> {:error, {:conflict, "user authentication factor already disabled"}}
      err -> err
    end
  end

  def enable(conn, %{"id" => id, "user_id" => user_id}) do
    with %Factor{is_active: false} = factor <- Factors.get_factor_by!(id: id, user_id: user_id),
         {:ok, %Factor{} = factor} <- Factors.update_factor(factor, %{"is_active" => true}) do
      conn
      |> put_view(AuthenticationFactorView)
      |> render("show.json", factor: factor)
    else
      %Factor{is_active: true} -> {:error, {:conflict, "user authentication factor already enabled"}}
      err -> err
    end
  end

  def reset(conn, %{"id" => id, "user_id" => user_id}) do
    factor = Factors.get_factor_by!(id: id, user_id: user_id, is_active: true)

    with {:ok, %Factor{} = factor} <- Factors.update_factor(factor, %{"factor" => nil}) do
      conn
      |> put_view(AuthenticationFactorView)
      |> render("show.json", factor: factor)
    end
  end
end
