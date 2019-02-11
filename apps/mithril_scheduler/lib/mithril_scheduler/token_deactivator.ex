defmodule MithrilScheduler.TokenAPI.Deactivator do
  @moduledoc false

  use Confex, otp_app: :mithril_scheduler
  use GenServer
  import Ecto.Query, warn: false
  alias Core.Repo
  alias Core.TokenAPI
  alias Core.TokenAPI.Token
  alias Core.UserAPI.User

  def start_link(name) do
    GenServer.start_link(__MODULE__, %{}, name: name)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:update_state, state}, _, _) do
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast(
        {:deactivate, caller},
        %{limit: limit} = state
      ) do
    rows_number = do_deactivate_old_password_tokens(state)

    if rows_number >= limit do
      GenServer.cast(:token_deactivator, {:deactivate, caller})
    else
      send(caller, :deactivated)
    end

    {:noreply, state}
  end

  def handle_cast(
        {:clean, caller},
        %{limit: limit} = state
      ) do
    rows_number = do_delete_expired_tokens(state)

    if rows_number >= limit do
      GenServer.cast(:token_cleaner, {:clean, caller})
    else
      send(caller, :cleaned)
    end

    {:noreply, state}
  end

  def deactivate_old_password_tokens do
    GenServer.call(:token_deactivator, {:update_state, state_options()})
    GenServer.cast(:token_deactivator, {:deactivate, self()})
  end

  def delete_expired_tokens do
    GenServer.call(:token_cleaner, {:update_state, state_options()})
    GenServer.cast(:token_cleaner, {:clean, self()})
  end

  defp state_options do
    expiration_days = Confex.fetch_env!(:core, :password)[:expiration]
    limit = config()[:limit]
    %{limit: limit, expiration_days: expiration_days}
  end

  def do_delete_expired_tokens(%{limit: limit}) do
    token_ttl_after_expiration_seconds = config()[:token_ttl_after_expiration] * (3600 * 24)
    expires_at = :os.system_time(:seconds) - token_ttl_after_expiration_seconds

    subquery_ids =
      Token
      |> select([t], %{id: t.id})
      |> where([t], t.expires_at <= ^expires_at)
      |> limit(^limit)

    {rows_deleted, _} =
      Token
      |> join(:inner, [t], ti in subquery(subquery_ids), t.id == ti.id)
      |> Repo.delete_all()

    rows_deleted
  end

  def do_deactivate_old_password_tokens(%{limit: limit, expiration_days: expiration_days}) do
    subquery_ids =
      Token
      |> select([t], %{id: t.id})
      |> join(
        :inner,
        [t],
        u in User,
        t.user_id == u.id and t.name not in [^TokenAPI.access_token_2fa(), ^TokenAPI.change_password_token()] and
          t.expires_at > ^:os.system_time(:seconds)
      )
      |> where(
        [t, u],
        u.password_set_at <= datetime_add(^NaiveDateTime.utc_now(), ^(-1 * expiration_days), "day")
      )
      |> limit(^limit)

    {rows_updated, _} =
      Token
      |> join(:inner, [t], tu in subquery(subquery_ids), t.id == tu.id)
      |> update(
        [t],
        set: [expires_at: ^:os.system_time(:seconds)]
      )
      |> Repo.update_all([])

    rows_updated
  end
end
