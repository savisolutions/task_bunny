defmodule TaskBunny.Initializer do
  @moduledoc """
  Handles initialization of queues process
  """
  alias TaskBunny.Queue
  require Logger

  @spec declare_queue(map) :: :ok
  def declare_queue(queue_config) do
    queue = queue_config.queue_name()
    host = queue_config.host() || :default

    supervisor_pid = Process.whereis(TaskBunny.Supervisor)
    TaskBunny.Connection.subscribe_connection(host, supervisor_pid)

    receive do
      {:connected, conn} -> declare_queue(conn, queue)
    after
      2_000 ->
        Logger.warn("""
        TaskBunny.Initializer: Failed to get connection for #{host}.
        TaskBunny can't declare the queues but carries on.
        """)
    end

    :ok
  end

  @spec declare_queue(AMQP.Connection.t(), String.t()) :: :ok
  def declare_queue(conn, queue) do
    Queue.declare_with_subqueues(conn, queue)
    :ok
  catch
    :exit, e ->
      # Handles the error but we carry on...
      # It's highly likely caused by the options on queue declare don't match.
      # We carry on with error log.
      Logger.warn("""
      TaskBunny.Initializer: Failed to declare queue for #{queue}.
      If you have changed the queue configuration, you have to delete the queue and create it again.
      Error: #{inspect(e)}
      """)

      {:error, {:exit, e}}
  end
end
