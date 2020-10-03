defmodule Mix.Tasks.TaskBunny.Queue.Reset do
  use Mix.Task

  @shortdoc "Reset queues for given jobs"

  @moduledoc """
  Mix task to reset queues for given jobs.

  It deletes the queues and creates them again.
  Therefore all messages in the queues are removed.
  """

  alias TaskBunny.{Config, Connection, Queue}

  @doc false
  @spec run(list) :: any
  def run(jobs) do
    _connections =
      Enum.map(Config.hosts(), fn host ->
        Connection.start_link(host)
      end)

    Enum.each(jobs, &reset_queue/1)
  end

  defp reset_queue(job) do
    Mix.shell().info("Resetting queues for #{inspect(job)}")
    host = job.host() || :default

    Queue.delete_with_subqueues(host, job.queue_name())
    Queue.declare_with_subqueues(host, job.queue_name())
  end
end
