defmodule Mithril.OTP.Terminator do
  @moduledoc """
    Process responsible for cancelation expired OTP
    Process runs once per day, in the night from 0 to 4 UTC
  """

  use GenServer

  alias Mithril.OTP

  # Client API

  @config Confex.get_env(:mithril_api, __MODULE__)

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  # Server API

  def init(_) do
    {:ok, schedule_next_run(@config[:frequency])}
  end

  def handle_cast({:terminate, ms}, _) do
    OTP.cancel_expired_otps()

    {:noreply, schedule_next_run(ms)}
  end

  defp schedule_next_run(ms) do
    unless Application.get_env(:mithril_api, :env) == :test do
      Process.send_after(self(), terminate_msg(ms), ms)
    end
  end

  defp terminate_msg(ms), do: {:"$gen_cast", {:terminate, ms}}
end
