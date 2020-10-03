defmodule TaskBunny.Supervisor do
  @moduledoc """
  Main supervisor for TaskBunny.

  It supervises Connection and WorkerSupervisor with one_for_all strategy.
  When Connection crashes it restarts all Worker processes through WorkerSupervisor
  so workers can always use a re-established connection.
  """
  use Supervisor
  alias TaskBunny.{Config, Connection, PublisherWorker, WorkerSupervisor}
  require Logger

  @doc false
  @spec start_link(Keyword.t()) :: {:ok, pid} | {:error, term}
  def start_link(opts) do
    name = Keyword.get(opts, :name, TaskBunny.Supervisor)
    workers = Keyword.get(opts, :workers, [])
    publisher = Keyword.get(opts, :publisher, {:publisher, []})
    Supervisor.start_link(__MODULE__, [workers, publisher], name: name)
  end

  @doc false
  @spec init(list()) ::
          {:ok, {:supervisor.sup_flags(), [Supervisor.Spec.spec()]}}
          | :ignore
  def init([workers, publisher_tuple]) do
    connections = connection_child_specs()
    publisher = publisher_child_spec(publisher_tuple)
    worker_children = worker_child_specs(workers)
    children = connections ++ publisher ++ worker_children

    Supervisor.init(children, strategy: :one_for_all)
  end

  defp worker_child_specs(queues) do
    [{TaskBunny.WorkerSupervisor, name: WorkerSupervisor, queues: queues}]
  end

  defp connection_child_specs do
    Enum.map(Config.hosts(), &worker(Connection, [&1], id: make_ref()))
  end

  defp publisher_child_spec({ps_name, queues}) do
    [:poolboy.child_spec(:publisher, publisher_config(ps_name))]
  end

  defp publisher_child_spec(_), do: []

  defp publisher_config(name) do
    [
      {:name, {:local, name}},
      {:worker_module, PublisherWorker},
      {:size, Config.publisher_pool_size()},
      {:max_overflow, Config.publisher_max_overflow()}
    ]
  end
end
