defmodule Mithril.Scheduler do
  @moduledoc false

  use Quantum.Scheduler, otp_app: :mithril_api

  alias Crontab.CronExpression.Parser
  alias Quantum.Job
  import Mithril.OTP, only: [cancel_expired_otps: 0]
  import Mithril.TokenAPI, only: [delete_expired_tokens: 0, deactivate_old_password_tokens: 0]

  def create_jobs do
    config = get_config()

    new_job(:otp_expiration, Parser.parse!(config[:otp_expiration]), &cancel_expired_otps/0)
    new_job(:token_deleting, Parser.parse!(config[:token_deleting]), &delete_expired_tokens/0)
    new_job(:token_expiration, Parser.parse!(config[:token_expiration]), &deactivate_old_password_tokens/0)
  end

  defp new_job(name, schedule, func) do
    __MODULE__.new_job()
    |> Job.set_name(name)
    |> Job.set_overlap(false)
    |> Job.set_schedule(schedule)
    |> Job.set_task(func)
    |> __MODULE__.add_job()
  end

  defp get_config do
    Confex.fetch_env!(:mithril_api, __MODULE__)
  end
end
