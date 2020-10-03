defmodule TaskBunny.WorkerSupervisor do
  @moduledoc """
  Supervises all TaskBunny workers.

  You don't have to call or start the Supervisor explicity.
  It will be automatically started by application and
  configure child workers based on configuration file.

  It also provides `graceful_halt/1` and `graceful_halt/2` that allow
  you to shutdown the worker processes safely.
  """
  use Supervisor
  alias TaskBunny.{Initializer, Worker}

  @doc false
  @spec start_link(Keyword.t()) :: {:ok, pid} | {:error, term}
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    queues = Keyword.get(opts, :queues, [])
    # FIXME do we want this here?
    Enum.each(queues, &Initializer.declare_queue/1)

    Supervisor.start_link(__MODULE__, queues, name: name)
  end

  defp queues_with_configuration(queues), do: Enum.map(queues, &queue_with_configuration/1)

  defp queue_with_configuration(job) do
    [
      queue: job.queue_name(),
      concurrency: job.concurrency() || default_concurrency(),
      store_rejected_jobs: job.store_rejected_jobs?(),
      host: job.host() || :default
    ]
  end

  defp default_concurrency, do: Application.get_env(:task_bunny, :default_concurrency, 2)

  @doc false
  @spec init(list) :: {:ok, {:supervisor.sup_flags(), [Supervisor.Spec.spec()]}} | :ignore
  def init(queues) do
    children =
      Enum.map(queues_with_configuration(queues), fn queue_config ->
        worker(
          Worker,
          [queue_config],
          id: "task_bunny.worker.#{queue_config[:queue]}"
        )
      end)

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Halts the job pocessing on workers gracefully.
  It makes workers to stop processing new jobs and waits for jobs currently running to finish.

  Note: It doesn't terminate any worker processes.
  The worker and worker supervisor processes will continue existing but won't consume any new messages.
  To resume it, terminate the worker supervisor then the main supervisor will start new processes.
  """
  @spec graceful_halt(pid | nil, integer) :: :ok | {:error, any}

  # When pid is not found. Assume it's already gone.
  def graceful_halt(nil, _timeout), do: :ok

  def graceful_halt(pid, timeout) do
    workers =
      pid
      |> Supervisor.which_children()
      |> Enum.map(fn {_, child, _, _} -> child end)
      |> Enum.filter(fn child -> is_pid(child) end)

    Enum.each(workers, fn worker ->
      Worker.stop_consumer(worker)
    end)

    case wait_for_all_jobs_done(workers, timeout) do
      true -> :ok
      false -> {:error, "Worker is busy"}
    end
  end

  @doc """
  Similar to graceful_halt/2 but gets pid from module name.
  """
  @spec graceful_halt(integer) :: :ok | {:error, any}
  def graceful_halt(timeout) do
    pid = Process.whereis(__MODULE__)
    graceful_halt(pid, timeout)
  end

  defp wait_for_all_jobs_done(workers, timeout) do
    Enum.find_value(0..round(timeout / 50), fn _ ->
      if workers_running?(workers) do
        :timer.sleep(50)
        false
      else
        true
      end
    end) || false
  end

  defp workers_running?(workers) do
    workers
    |> Enum.any?(fn pid -> worker_running?(pid) end)
  end

  defp worker_running?(pid) when is_pid(pid) do
    %{runners: runners, consuming: consuming} = GenServer.call(pid, :status)
    runners > 0 || consuming
  end

  defp worker_running?(_), do: false
end
