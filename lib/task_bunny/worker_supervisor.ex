defmodule TaskBunny.WorkerSupervisor do
  use Supervisor

  def start_link(jobs) do
    Supervisor.start_link(__MODULE__, jobs)
  end

  def init(jobs) do
    jobs
    |> Enum.map(fn ({job, concurrency}) ->
         worker(
          TaskBunny.Worker,
          [{job, concurrency}],
          id: "task_bunny.worker.#{job.queue_name}"
        )
       end)
    |> supervise(strategy: :one_for_one)
  end
end