defmodule Mithril.Web.FallbackController do
  @moduledoc """
  This controller should be used as `action_fallback` in rest of controllers to remove duplicated error handling.
  """
  use Mithril.Web, :controller
  alias EView.Views.{ValidationError, Error}

  def call(conn, {:error, :access_denied}) do
    conn
    |> put_status(:unauthorized)
    |> render(Error, :"401")
  end

  def call(conn, {:error, {:access_denied, reason}}) when is_map(reason) do
    conn
    |> put_status(:unauthorized)
    |> render(EView.Views.Error, :"401", reason)
  end

  def call(conn, {:error, {:too_many_requests, reason}}) when is_map(reason) do
    conn
    |> put_status(:too_many_requests)
    |> render(EView.Views.Error, :"401", reason)
  end

  def call(conn, {:error, {:access_denied, reason}}) do
    conn
    |> put_status(:unauthorized)
    |> render(EView.Views.Error, :"401", %{message: reason})
  end

  def call(conn, {:error, {:password_expired, reason}}) do
    conn
    |> put_status(:unauthorized)
    |> render(EView.Views.Error, :"401", %{message: reason, type: :password_expired})
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> render(Error, :"404")
  end

  def call(conn, nil) do
    conn
    |> put_status(:not_found)
    |> render(Error, :"404")
  end

  def call(conn, {:error, {:conflict, reason}}) do
    call(conn, {:conflict, reason})
  end

  def call(conn, {:conflict, reason}) do
    conn
    |> put_status(:conflict)
    |> render(Error, :"409", %{message: reason})
  end

  def call(conn, {:error, {:"422", error}}) do
    conn
    |> put_status(422)
    |> render(Error, :"400", %{message: error})
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(ValidationError, :"422", changeset)
  end

  def call(conn, %Ecto.Changeset{valid?: false} = changeset) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(ValidationError, :"422", changeset)
  end

  def call(conn, {:error, {:unprocessable_entity, error}}) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(EView.Views.Error, :"400", %{message: error})
  end

  def call(conn, {:error, {:service_unavailable, reason}}) do
    conn
    |> put_status(:service_unavailable)
    |> render(EView.Views.Error, :"503", %{message: reason})
  end
end
