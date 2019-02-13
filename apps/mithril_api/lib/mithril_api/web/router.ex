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
  end

  pipeline :api_consumer_id do
    plug(:header_required, "x-consumer-id")
    plug(:put_user_id_header)
  end

  pipeline :api_key do
    plug(:put_api_key_header)
  end

  pipeline :jwt do
    plug(Guardian.Plug.Pipeline, module: Core.Guardian, error_handler: Mithril.Web.FallbackController)
  end

  pipeline :jwt_access_registration do
    plug(Guardian.Plug.VerifyHeader, claims: %{typ: "access", aud: Core.Guardian.get_aud(:registration)})
    plug(Guardian.Plug.EnsureAuthenticated)
  end

  scope "/api", Mithril.Web do
    pipe_through([:api, :jwt, :jwt_access_registration])
    post("/send_otp", OTPController, :send_otp)
    post("/verifications", OTPController, :verifications)
  end

  scope "/oauth", as: :oauth2, alias: Mithril do
    pipe_through(:api)

    # generate nonce for Sign in
    post("/nonce", OAuth.NonceController, :nonce)

    scope "/apps" do
      pipe_through([:api_consumer_id, :api_key])
      post("/authorize", OAuth.AppController, :authorize)
    end

    post("/tokens", OAuth.TokenController, :create, assigns: %{grant_types: ~w(authorization_code refresh_token)})
    post("/tokens/actions/change_password", OAuth.TokenController, :create_change_pwd_token)

    # 2FA
    post("/users/actions/init_factor", OAuth.TokenController, :init_factor)
    post("/users/actions/approve_factor", OAuth.TokenController, :approve_factor)
    post("/users/actions/update_password", OAuth.TokenController, :update_password)
  end

  scope "/auth", as: :auth, alias: Mithril do
    pipe_through(:api)
    post("/login", OAuth.TokenController, :create, assigns: %{grant_types: ~w(
      password
      change_password
      digital_signature
      authorize_2fa_access_token
      refresh_2fa_access_token
    )})
  end

  scope "/admin", Mithril.Web do
    pipe_through(:api)

    resources "/users", UserController, except: [:new, :edit] do
      post("/global_roles", GlobalUserRoleController, :create, as: :global_role)
      get("/global_roles/:id", GlobalUserRoleController, :show, as: :global_role)
      resources("/roles", UserRoleController, except: [:new, :edit, :update, :delete], as: :role)
      delete("/roles", UserRoleController, :delete_by_user, as: :role)
      delete("/tokens", TokenController, :delete_by_user)
      delete("/apps", AppController, :delete_by_user)

      post("/tokens/access", TokenController, :create_access_token)

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
      patch("/actions/deactivate_tokens", ClientController, :deactivate_tokens, as: :actions)

      # connections
      get("/connections", ConnectionController, :index)
      get("/connections/:id", ConnectionController, :show)
      put("/connections", ConnectionController, :upsert)
      patch("/connections/:id", ConnectionController, :update)
      patch("/connections/:id/actions/refresh_secret", ConnectionController, :refresh_secret)
      delete("/connections/:id", ConnectionController, :delete)
    end

    resources "/tokens", TokenController, except: [:new, :edit] do
      get("/verify", TokenController, :verify, as: :verify)
      get("/user", TokenController, :user, as: :user)
    end

    delete("/tokens", TokenController, :delete_by_user_ids)

    resources("/client_types", ClientTypeController, except: [:new, :edit])
    resources("/roles", RoleController, except: [:new, :edit])
    get("/otps", OTPController, :index)

    scope "/apps" do
      pipe_through([:api_consumer_id])
      resources("/", AppController, except: [:new, :edit])
    end
  end

  defp handle_errors(%Plug.Conn{status: 500} = conn, %{kind: kind, reason: reason, stack: stacktrace}) do
    LoggerJSON.log_error(kind, reason, stacktrace)
    send_resp(conn, 500, Poison.encode!(%{errors: %{detail: "Internal server error"}}))
  end

  defp handle_errors(_, _), do: nil
end
