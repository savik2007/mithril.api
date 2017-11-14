defmodule MithrilWeb.Router do
  @moduledoc """
  The router provides a set of macros for generating routes
  that dispatch to specific controllers and actions.
  Those macros are named after HTTP verbs.

  More info at: https://hexdocs.pm/phoenix/Phoenix.Router.html
  """
  use Mithril.Web, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug :put_secure_browser_headers

    # You can allow JSONP requests by uncommenting this line:
    # plug :allow_jsonp
  end

  scope "/oauth", as: :oauth2, alias: Mithril do
    pipe_through :api

    post "/apps/authorize", OAuth.AppController, :authorize
    post "/tokens",         OAuth.TokenController, :create
  end

  scope "/admin", Mithril.Web do
    pipe_through :api

    resources "/users", UserController, except: [:new, :edit] do
      resources "/roles", UserRoleController, except: [:new, :edit, :update, :delete], as: :role
      delete "/roles", UserRoleController, :delete_by_user, as: :role
      delete "/tokens", TokenController, :delete_by_user
      delete "/apps", AppController, :delete_by_user

      patch "/actions/change_password", UserController, :change_password
      patch "/actions/block", UserController, :block
      patch "/actions/unblock", UserController, :unblock

      resources "/authentication_factors", AuthenticationFactorController,
        except: [:new, :edit, :delete], as: :authentication_factor
      patch "/authentication_factors/:id/actions/reset", AuthenticationFactorController, :reset,
        as: :authentication_factor
      patch "/authentication_factors/:id/actions/disable", AuthenticationFactorController, :disable,
        as: :authentication_factor
      patch "/authentication_factors/:id/actions/enable", AuthenticationFactorController, :enable,
        as: :authentication_factor
    end

    get "/user_roles", UserRoleController, :index, as: :user_roles
    delete "/users/roles/:id", UserRoleController, :delete

    resources "/clients", ClientController, except: [:new, :edit] do
      get "/details", ClientController, :details, as: :details
      patch "/refresh_secret", ClientController, :refresh_secret, as: :refresh_secret
    end

    resources "/tokens", TokenController, except: [:new, :edit] do
      get "/verify", TokenController, :verify, as: :verify
      get "/user", TokenController, :user, as: :user
    end
    delete "/tokens", TokenController, :delete_by_user_ids

    resources "/apps", AppController, except: [:new, :edit]
    resources "/client_types", ClientTypeController, except: [:new, :edit]
    resources "/roles", RoleController, except: [:new, :edit]
  end
end
