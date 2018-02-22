defmodule MithrilWeb.Router do
  @moduledoc """
  The router provides a set of macros for generating routes
  that dispatch to specific controllers and actions.
  Those macros are named after HTTP verbs.

  More info at: https://hexdocs.pm/phoenix/Phoenix.Router.html
  """
  use Mithril.Web, :router
  use Plug.ErrorHandler

  alias Plug.LoggerJSON

  require Logger

  pipeline :api do
    plug(:accepts, ["json"])
    plug(:put_secure_browser_headers)

    # You can allow JSONP requests by uncommenting this line:
    # plug :allow_jsonp
  end

  scope "/", Mithril.Web do
    pipe_through(:api)
    # registration
    post("/send_email_verification", RegistrationController, :send_email_verification)
  end

  scope "/oauth", as: :oauth2, alias: Mithril do
    pipe_through(:api)

    post("/apps/authorize", OAuth.AppController, :authorize)
    post("/tokens", OAuth.TokenController, :create)
    post("/tokens/actions/change_password", OAuth.TokenController, :create_change_pwd_token)

    # 2FA
    post("/users/actions/init_factor", OAuth.TokenController, :init_factor)
    post("/users/actions/approve_factor", OAuth.TokenController, :approve_factor)
    post("/users/actions/update_password", OAuth.TokenController, :update_password)
  end

  scope "/admin", Mithril.Web do
    pipe_through(:api)

    resources "/users", UserController, except: [:new, :edit] do
      resources("/roles", UserRoleController, except: [:new, :edit, :update, :delete], as: :role)
      delete("/roles", UserRoleController, :delete_by_user, as: :role)
      delete("/tokens", TokenController, :delete_by_user)
      delete("/apps", AppController, :delete_by_user)

      patch("/actions/change_password", UserController, :change_password)
      patch("/actions/block", UserController, :block)
      patch("/actions/unblock", UserController, :unblock)

      resources(
        "/authentication_factors",
        AuthenticationFactorController,
        except: [:new, :update, :edit, :delete],
        as: :authentication_factor
      )

      patch(
        "/authentication_factors/:id/actions/reset",
        AuthenticationFactorController,
        :reset,
        as: :authentication_factor
      )

      patch(
        "/authentication_factors/:id/actions/disable",
        AuthenticationFactorController,
        :disable,
        as: :authentication_factor
      )

      patch(
        "/authentication_factors/:id/actions/enable",
        AuthenticationFactorController,
        :enable,
        as: :authentication_factor
      )
    end

    get("/user_roles", UserRoleController, :index, as: :user_roles)
    delete("/users/roles/:id", UserRoleController, :delete)

    resources "/clients", ClientController, except: [:new, :edit] do
      get("/details", ClientController, :details, as: :details)
      patch("/refresh_secret", ClientController, :refresh_secret, as: :refresh_secret)
    end

    resources "/tokens", TokenController, except: [:new, :edit] do
      get("/verify", TokenController, :verify, as: :verify)
      get("/user", TokenController, :user, as: :user)
    end

    delete("/tokens", TokenController, :delete_by_user_ids)

    resources("/apps", AppController, except: [:new, :edit])
    resources("/client_types", ClientTypeController, except: [:new, :edit])
    resources("/roles", RoleController, except: [:new, :edit])
    get("/otps", OTPController, :index)
  end

  defp handle_errors(%Plug.Conn{status: 500} = conn, %{kind: kind, reason: reason, stack: stacktrace}) do
    LoggerJSON.log_error(kind, reason, stacktrace)
    send_resp(conn, 500, Poison.encode!(%{errors: %{detail: "Internal server error"}}))
  end

  defp handle_errors(_, _), do: nil
end
