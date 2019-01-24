defmodule Mithril.Authorization.LoginHistory do
  @moduledoc """
    Module which handles failed login history.
    Currently supports only wrong password events type.
    Can be extended to support invalid factor types
  """

  alias Mithril.Error
  alias Mithril.UserAPI
  alias Mithril.UserAPI.User
  alias Mithril.UserAPI.User.LoginHstr

  @type_otp "otp"
  @type_password "password"

  def type(:otp), do: @type_otp
  def type(:password), do: @type_password

  def check_failed_login(%User{} = user, @type_password) do
    conf = Confex.get_env(:mithril_api, :password)
    max_logins = conf[:max_failed_logins]
    max_logins_period = conf[:max_failed_logins_period]

    do_check_login(user, @type_password, max_logins, max_logins_period)
  end

  def check_sent_otps(%User{} = user) do
    conf = Confex.get_env(:mithril_api, :"2fa")
    otp_send_timeout = conf[:otp_send_timeout]
    otp_send_counter = conf[:otp_send_counter_max]

    do_check_login(user, @type_otp, otp_send_counter, otp_send_timeout)
  end

  defp do_check_login(user, type, max_logins, max_logins_period) do
    logins =
      user
      |> get_logins(type)
      |> Enum.filter(&filter_by_period(&1, max_logins_period))

    if length(logins) >= max_logins do
      case type do
        @type_otp -> {:error, :otp_timeout}
        @type_password -> Error.login_reached_max_attempts()
      end
    else
      :ok
    end
  end

  def filter_by_period(%LoginHstr{time: time}, max_logins_period) do
    period_start = NaiveDateTime.add(NaiveDateTime.utc_now(), -max_logins_period * 60, :second)

    case NaiveDateTime.compare(time, period_start) do
      :lt -> false
      _ -> true
    end
  end

  def clear_logins(%User{} = user, type) do
    UserAPI.merge_user_priv_settings(user, %{login_hstr: get_other_logins(user, type)})
  end

  def add_failed_login(%User{} = user, @type_password = type) do
    do_add_login(user, type, Confex.get_env(:mithril_api, :password)[:max_failed_logins], false)
  end

  def add_login(%User{} = user, @type_otp = type, is_success) do
    do_add_login(user, type, Confex.get_env(:mithril_api, :"2fa")[:otp_send_counter_max], is_success)
  end

  defp do_add_login(%User{} = user, type, max_logins, is_success) do
    logins = do_add_login(get_logins(user, type), max_logins, type, is_success)
    other_logins = get_other_logins(user, type)
    UserAPI.merge_user_priv_settings(user, %{login_hstr: convert_structs(logins ++ other_logins)})
  end

  defp do_add_login(logins, max_items, type, is_success)
       when is_list(logins) and is_integer(max_items) and is_boolean(is_success) do
    [
      %{
        "type" => type,
        "is_success" => is_success,
        "time" => NaiveDateTime.utc_now()
      }
      | Enum.slice(logins, 0, max_items - 1)
    ]
  end

  def get_logins(%User{priv_settings: priv_settings}, type) do
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
