defmodule Mithril.Authorization.LoginHistory do
  @moduledoc """
    Module which handles failed login history.
    Currently supports only wrong password events type.
    Can be extended to support invalid factor types
  """

  alias Mithril.UserAPI
  alias Mithril.UserAPI.User

  @type_password "password"

  def type(:password), do: @type_password

  def clear_failed_logins(%User{} = user, type) do
    UserAPI.merge_user_priv_settings(user, %{login_hstr: get_other_logins(user, type)})
  end

  def add_failed_login(%User{} = user, type) do
    max_failed_logins = Confex.get_env(:mithril_api, :password)[:max_failed_logins]
    failed_logins = do_add_failed_login(get_failed_logins(user, type), max_failed_logins, type)
    other_logins = get_other_logins(user, type)
    UserAPI.merge_user_priv_settings(user, %{login_hstr: convert_structs(failed_logins ++ other_logins)})
  end

  defp do_add_failed_login(failed_logins, max_items, type) when is_list(failed_logins) and is_integer(max_items) do
    [
      %{
        "type" => type,
        "is_success" => false,
        "time" => NaiveDateTime.utc_now(),
      } | Enum.slice(failed_logins, 0, max_items - 1)
    ]
  end

  def get_failed_logins(%User{priv_settings: priv_settings}, type) do
    Enum.filter(priv_settings.login_hstr, &(Map.get(&1, :type) == type))
  end

  def get_other_logins(%User{priv_settings: priv_settings}, type) do
    Enum.filter(priv_settings.login_hstr, &(Map.get(&1, :type) != type))
  end

  defp convert_structs(values) do
    Enum.map(values, fn
      %{__struct__: _} = value -> Map.from_struct(value)
      value -> value
    end)
  end
end
