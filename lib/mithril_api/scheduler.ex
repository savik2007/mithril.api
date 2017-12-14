defmodule Mithril.Scheduler do
  @moduledoc false

  use Quantum.Scheduler, otp_app: :mithril_api

  alias Crontab.CronExpression.Parser
  alias Quantum.Job
  import Mithril.TokenAPI, only: [deactivate_old_password_tokens: 0]

  def create_jobs do
    __MODULE__.new_job()
    |> Job.set_name(:token_expiration)
    |> Job.set_overlap(false)
    |> Job.set_schedule(Parser.parse!(get_config()[:token_expiration]))
    |> Job.set_task(&deactivate_old_password_tokens/0)
    |> __MODULE__.add_job()
  end

  defp get_config do
    Confex.fetch_env!(:mithril_api, __MODULE__)
  end
end
