defmodule Mithril.UserAPI do
  @moduledoc """
  The boundary for the UserAPI system.
  """
  use Mithril.Search

  import Ecto.{Query, Changeset}, warn: false

  alias Ecto.Multi
  alias Mithril.Repo
  alias Mithril.TokenAPI
  alias Mithril.UserAPI.{User, UserSearch}
  alias Mithril.UserAPI.User.PrivSettings
  alias Mithril.Authentication

  def list_users(params) do
    %UserSearch{}
    |> user_changeset(params)
    |> search(params, User)
  end

  def get_search_query(entity, %{ids: _} = changes) do
    changes =
      changes
      |> Map.put(:id, changes.ids)
      |> Map.delete(:ids)

    super(entity, changes)
  end
  def get_search_query(entity, changes) do
    super(entity, changes)
  end

  def get_user(id), do: Repo.get(User, id)
  def get_user!(id), do: Repo.get!(User, id)
  def get_user_by(attrs), do: Repo.get_by(User, attrs)

  def get_full_user(user_id, client_id) do
    query = from u in User,
                 left_join: ur in assoc(u, :user_roles),
                 left_join: r in assoc(ur, :role),
                 preload: [
                   roles: r
                 ],
                 where: ur.user_id == ^user_id,
                 where: ur.client_id == ^client_id

    Repo.one(query)
  end

  def create_user(attrs \\ %{}) do
    user = %User{
      priv_settings: %{
        login_error_counter: 0,
        otp_error_counter: 0
      }
    }
    user_changeset = user_changeset(user, attrs)
    Multi.new
    |> Multi.insert(:user, user_changeset)
    |> Multi.run(:authentication_factors, &create_user_factor(&1, attrs))
    |> Repo.transaction()
    |> case do
         {:ok, %{user: user}} -> {:ok, user}
         {:error, _, err, _} -> {:error, err}
       end
  end

  defp create_user_factor(%{user: user}, attrs) do
    case enabled_2fa?(attrs) do
      true -> Authentication.create_factor(%{type: Authentication.type(:sms), user_id: user.id})
      false -> {:ok, :not_enabled}
    end
  end

  defp enabled_2fa?(attrs) do
    case Map.has_key?(attrs, "2fa_enable") do
      true -> Map.get(attrs, "2fa_enable") == true
      _ -> Confex.get_env(:mithril_api, :"2fa")[:user_2fa_enabled?]
    end
  end

  def update_user(%User{} = user, attrs) do
    user
    |> user_changeset(attrs)
    |> Repo.update()
  end

  def merge_user_priv_settings(%User{priv_settings: priv_settings} = user, new_settings) when is_map(new_settings) do
    data = priv_settings
           |> Map.from_struct()
           |> Map.merge(new_settings)
    update_user_priv_settings(user, data)
  end

  def update_user_priv_settings(%User{} = user, priv_settings) do
    user
    |> cast(%{priv_settings: priv_settings}, [])
    |> cast_embed(:priv_settings, with: &priv_settings_changeset/2)
    |> Repo.update()
  end

  def block_user(%User{} = user, reason \\ nil) do
    user
    |> user_changeset(%{is_blocked: true, block_reason: reason})
    |> Repo.update()
    |> expire_user_tokens()
  end

  def expire_user_tokens({:ok, user} = resp) do
    TokenAPI.deactivate_tokens_by_user(user)
    resp
  end
  def expire_user_tokens(err) do
    err
  end

  def unblock_user(%User{} = user, reason \\ nil) do
    attrs = %{is_blocked: false, block_reason: reason, priv_settings: %{login_error_counter: 0, otp_error_counter: 0}}
    user
    |> cast(attrs, [:is_blocked, :block_reason])
    |> cast_embed(:priv_settings, with: &priv_settings_changeset/2)
    |> Repo.update()
  end

  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  def change_user(%User{} = user) do
    user_changeset(user, %{})
  end

  def change_user_password(%User{} = user, user_params) do
    changeset =
      user
      |> user_changeset(user_params)
      |> validate_required([:current_password])
      |> validate_changed(:password)
      |> validate_passwords_match(:password, :current_password)

    Repo.update(changeset)
  end

  defp get_password_hash(password) do
    Comeonin.Bcrypt.hashpwsalt(password)
  end

  defp user_changeset(%User{} = user, attrs) do
    user
    |> cast(attrs, [:email, :password, :settings, :current_password, :is_blocked, :block_reason])
    |> validate_required([:email, :password])
    |> unique_constraint(:email)
    |> validate_length(:password, min: 8)
    |> validate_format(:password, ~r/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/,
      message: "password should contain both upper and lowercase letters, numbers"
    )
    |> put_password()
  end
  defp user_changeset(%UserSearch{} = user_role, attrs) do
    cast(user_role, attrs, UserSearch.__schema__(:fields))
  end

  defp priv_settings_changeset(%PrivSettings{} = priv_settings, attrs) do
    cast(priv_settings, attrs, [:login_error_counter, :otp_error_counter, :last_send_otp_timestamp, :otp_send_counter])
  end

  defp put_password(changeset) do
    if password = get_change(changeset, :password) do
      changeset
      |> put_change(:password, get_password_hash(password))
      |> put_change(:password_set_at, NaiveDateTime.utc_now())
    else
      changeset
    end
  end

  defp validate_changed(changeset, field) do
    case fetch_change(changeset, field) do
      :error -> add_error(changeset, field, "is not changed", validation: :required)
      {:ok, _change} -> changeset
    end
  end

  defp validate_passwords_match(changeset, field1, field2) do
    validate_change changeset, field1, :password, fn _, _new_value ->
      %{data: data} = changeset
      field1_hash = Map.get(data, field1)

      with {:ok, value2} <- fetch_change(changeset, field2),
           true <- Comeonin.Bcrypt.checkpw(value2, field1_hash) do
        []
      else
        :error ->
          []
        false ->
          [{field2,
            {"#{to_string(field1)} does not match password in field #{to_string(field2)}", [validation: :password]}}]
      end
    end
  end
end
