defmodule Mithril.UserAPI do
  @moduledoc """
  The boundary for the UserAPI system.
  """
  import Mithril.Search

  import Ecto.{Query, Changeset}, warn: false
  import EView.Changeset.Validators.Email

  alias Ecto.Multi
  alias Mithril.Authentication
  alias Mithril.Authentication.Factor
  alias Mithril.Authentication.Factors
  alias Mithril.Repo
  alias Mithril.TokenAPI
  alias Mithril.UserAPI.PasswordHistory
  alias Mithril.UserAPI.User
  alias Mithril.UserAPI.User.PrivSettings
  alias Mithril.UserAPI.UserSearch

  @fields_optional ~w(tax_id person_id settings current_password is_blocked block_reason)a
  @fields_required ~w(email password)a

  def list_users(params) do
    %UserSearch{}
    |> user_changeset(params)
    |> search(params, User)
  end

  def get_user(id), do: Repo.get(User, id)
  def get_user!(id), do: Repo.get!(User, id)
  def get_user_by(attrs), do: Repo.get_by(User, attrs)

  def get_user_with_roles(user_id, client_id) do
    query =
      from(
        u in User,
        left_join: ur in assoc(u, :user_roles),
        on: ur.user_id == u.id and ur.client_id == ^client_id,
        left_join: r in assoc(ur, :role),
        left_join: gur in assoc(u, :global_user_roles),
        on: gur.user_id == u.id,
        left_join: gr in assoc(gur, :role),
        where: u.id == ^user_id,
        preload: [
          roles: r,
          global_roles: gr
        ]
      )

    Repo.one(query)
  end

  def create_user(attrs \\ %{}) do
    user = %User{
      priv_settings: %{
        otp_error_counter: 0
      }
    }

    user_changeset = user_changeset(user, attrs)

    Multi.new()
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
      true ->
        attrs
        |> Map.merge(%{"type" => Authentication.type(:sms), "user_id" => user.id, "email" => user.email})
        |> Factors.create_factor()

      false ->
        {:ok, :not_enabled}
    end
  end

  defp create_or_update_user_factor(%{user: %{factor: nil}} = user, %{"factor" => _} = attrs) do
    create_user_factor(user, attrs)
  end

  defp create_or_update_user_factor(%{user: %{factor: %Factor{} = factor} = user}, %{"factor" => _} = attrs) do
    case enabled_2fa?(attrs) do
      true ->
        Factors.update_factor(factor, Map.put(attrs, "email", user.email))

      false ->
        {:ok, :not_enabled}
    end
  end

  defp create_or_update_user_factor(_, _), do: {:ok, :not_set}

  defp enabled_2fa?(attrs) do
    case Map.has_key?(attrs, "2fa_enable") do
      true -> Map.get(attrs, "2fa_enable") == true
      _ -> Confex.get_env(:mithril_api, :"2fa")[:user_2fa_enabled?]
    end
  end

  def update_user(%User{} = user, attrs) do
    user_changeset = user_changeset(user, attrs)

    Multi.new()
    |> Multi.update(:user, user_changeset)
    |> Multi.run(:authentication_factors, &create_or_update_user_factor(&1, attrs))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, _, err, _} -> {:error, err}
    end
  end

  def merge_user_priv_settings(%User{priv_settings: priv_settings} = user, new_settings) when is_map(new_settings) do
    data =
      priv_settings
      |> Map.merge(new_settings)
      |> to_map()

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
    attrs = %{is_blocked: false, block_reason: reason, priv_settings: %{login_hstr: [], otp_error_counter: 0}}

    user
    |> cast(attrs, [:is_blocked, :block_reason])
    |> cast_embed(:priv_settings, with: &priv_settings_changeset/2)
    |> Repo.update()
  end

  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  def change_user_password(%User{} = user, user_params) do
    elem(
      Repo.transaction(fn ->
        changeset =
          user
          |> user_changeset(user_params)
          |> validate_required([:current_password])
          |> validate_changed(:password)
          |> validate_passwords_match(:password, :current_password)

        Repo.update(changeset)
      end),
      1
    )
  end

  def update_user_password(user_id, password) do
    with user <- get_user(user_id),
         changeset = user_changeset(user, %{password: password}),
         {:ok, user} <- Repo.update(changeset),
         do: {:ok, user}
  end

  defp get_password_hash(password) do
    Comeonin.Bcrypt.hashpwsalt(password)
  end

  defp user_changeset(%User{} = user, attrs) do
    user
    |> cast(attrs, @fields_optional ++ @fields_required)
    |> validate_required(@fields_required)
    |> update_change(:email, &String.downcase/1)
    |> validate_email(:email)
    |> unique_constraint(:email)
    |> validate_length(:password, min: 12)
    |> validate_format(
      :password,
      ~r/^(?=.*[a-zа-яёїієґ])(?=.*[A-ZА-ЯЁЇIЄҐ])(?=.*\d)/,
      message: "Password does not meet complexity requirements"
    )
    |> put_password(user)
  end

  defp user_changeset(%UserSearch{} = user_role, attrs) do
    user_role
    |> cast(attrs, UserSearch.__schema__(:fields))
    |> put_search_change()
  end

  defp put_search_change(%Ecto.Changeset{valid?: true, changes: %{ids: ids}} = changeset) do
    changeset
    |> put_change(:id, ids)
    |> delete_change(:ids)
  end

  defp put_search_change(changeset), do: changeset

  defp priv_settings_changeset(%PrivSettings{} = priv_settings, attrs) do
    priv_settings
    |> cast(attrs, [:otp_error_counter])
    |> cast_embed(:login_hstr)
  end

  defp put_password(changeset, %User{} = user) do
    password = get_change(changeset, :password)

    if password do
      changeset
      |> put_change(:password, get_password_hash(password))
      |> validate_previous_passwords(user, password)
      |> put_change(:password_set_at, NaiveDateTime.utc_now())
    else
      changeset
    end
  end

  defp validate_previous_passwords(changeset, %User{id: nil}, _), do: changeset

  defp validate_previous_passwords(changeset, %User{id: id}, password) do
    previous_passwords =
      PasswordHistory
      |> where([ph], ph.user_id == ^id)
      |> order_by([ph], asc: ph.id)
      |> Repo.all()

    already_used =
      Enum.any?(previous_passwords, fn previous_password ->
        Comeonin.Bcrypt.checkpw(password, previous_password.password)
      end)

    if already_used do
      add_error(
        changeset,
        :password,
        "This password has been used recently. Try another one",
        validation: :password_used
      )
    else
      if length(previous_passwords) > 2 do
        previous_passwords
        |> hd()
        |> Repo.delete()
      end

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
    validate_change(changeset, field1, :password, fn _, _new_value ->
      %{data: data} = changeset
      field1_hash = Map.get(data, field1)

      with {:ok, value2} <- fetch_change(changeset, field2),
           true <- Comeonin.Bcrypt.checkpw(value2, field1_hash) do
        []
      else
        :error ->
          []

        false ->
          [
            {field2,
             {"#{to_string(field1)} does not match password in field #{to_string(field2)}", [validation: :password]}}
          ]
      end
    end)
  end

  defp to_map(%_{} = data) do
    data
    |> Map.from_struct()
    |> Enum.map(&to_map/1)
    |> Enum.into(%{})
  end

  defp to_map({key, list}) when is_list(list) do
    {key, Enum.map(list, &to_map/1)}
  end

  defp to_map({key, %_{} = value}) do
    {key, Map.from_struct(value)}
  end

  defp to_map(field) do
    field
  end
end
