defmodule Mithril.Web.FallbackController do
  @moduledoc """
  This controller should be used as `action_fallback` in rest of controllers to remove duplicated error handling.
  """
  use Mithril.Web, :controller
  alias EView.Views.Error
  alias EView.Views.ValidationError

  def call(conn, {:error, {:bad_request, reason}}) when is_binary(reason) do
    conn
    |> put_status(:bad_request)
    |> render(Error, :"400", %{message: reason})
  end

  def call(conn, {:error, :access_denied}) do
    conn
    |> put_status(:unauthorized)
    |> render(Error, :"401")
  end

  def call(conn, {:error, {:access_denied, reason}}) when is_map(reason) do
    conn
    |> put_status(:unauthorized)
    |> render(Error, :"401", reason)
  end

  def call(conn, {:error, {:access_denied, reason}}) do
    conn
    |> put_status(:unauthorized)
    |> render(Error, :"401", %{message: reason})
  end

  def call(conn, {:error, {:too_many_requests, reason}}) when is_map(reason) do
    conn
    |> put_status(:too_many_requests)
    |> render(Error, :"401", reason)
  end

  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> render(Error, :"403")
  end

  def call(conn, {:error, {:forbidden, reason}}) when is_map(reason) do
    conn
    |> put_status(:forbidden)
    |> render(Error, :"403", reason)
  end

  def call(conn, {:error, {:password_expired, reason}}) do
    conn
    |> put_status(:unauthorized)
    |> render(Error, :"401", %{message: reason, type: :password_expired})
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

  def call(conn, %Ecto.Changeset{valid?: false} = changeset) do
    call(conn, {:error, changeset})
  end

  def call(conn, {:error, %Ecto.Changeset{valid?: false} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(ValidationError, :"422", changeset)
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset, _status_code}), do: call(conn, {:error, changeset})

  def call(conn, {:error, {:unprocessable_entity, error}}) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(Error, :"400", %{message: error})
  end

  def call(conn, {:error, {:internal_error, reason}}) do
    conn
    |> put_status(:internal_error)
    |> render(Error, :"500", %{message: reason})
  end

  def call(conn, {:error, {:service_unavailable, reason}}) do
    conn
    |> put_status(:service_unavailable)
    |> render(Error, :"503", %{message: reason})
  end

  @doc """
  Proxy response from APIs
  """
  def call(conn, {_, %{"meta" => %{}} = proxy_resp}) do
    proxy(conn, proxy_resp)
  end

  @doc """
  Guardian error messages
  """
  def auth_error(conn, {:invalid_token, :token_expired}, _opts) do
    call(conn, {:error, {:access_denied, %{message: "JWT expired", type: :jwt_expired}}})
  end

  def auth_error(conn, {:invalid_token, "aud"}, _opts) do
    call(conn, {:error, {:access_denied, %{message: "JWT is not permitted for this action", type: :jwt_aud_invalid}}})
  end

  def auth_error(conn, _, _opts) do
    call(conn, {:error, :access_denied})
  end
end
