defmodule TaskBunny.Config do
  @moduledoc """
  Handles TaskBunny configuration.
  """
  alias TaskBunny.ConfigError

  @default_concurrency 2

  @doc """
  Returns list of hosts.
  """
  @spec hosts :: [atom]
  def hosts do
    hosts_config()
    |> Enum.map(fn {host, _options} -> host end)
  end

  @doc """
  Returns configuration for the host.

  ## Examples

      iex> host_config(:default)
      [connection_options: "amqp://localhost?heartbeat=30"]

  """
  @spec host_config(atom) :: keyword | nil
  def host_config(host) do
    hosts_config()[host]
  end

  @doc """
  Returns connect options for the host.
  """
  @spec connect_options(host :: atom) :: list | String.t()
  def connect_options(host) do
    hosts_config()[host][:connect_options] ||
      raise ConfigError, message: "Can not find host '#{host}' in config"
  end

  @doc """
  Returns list of queues.
  """
  @spec queues :: [keyword]
  def queues do
    :task_bunny
    |> Application.get_all_env()
    |> Enum.filter(fn {key, _} ->
      is_atom(key) && Atom.to_string(key) =~ ~r/queue$/
    end)
    |> Enum.map(fn {_, queue_config} -> parse_queue_config(queue_config) end)
    |> Enum.flat_map(fn queue_list -> queue_list end)
  end

  # Get queue config and returns list of queues with namespace
  defp parse_queue_config(queue_config) do
    namespace = queue_config[:namespace] || ""

    queue_config[:queues]
    |> Enum.map(fn queue ->
      unless queue[:name] do
        raise ConfigError, message: "name is missing in queue definition. #{inspect(queue)}"
      end

      Keyword.merge(queue, name: namespace <> queue[:name])
    end)
  end

  @doc """
  Transforms queue configuration into list of workers for the application to run.
  """
  @spec workers :: [keyword]
  def workers do
    queues()
    |> Enum.filter(&worker_enabled?/1)
    |> Enum.map(fn queue ->
      concurrency =
        if queue[:worker] && queue[:worker][:concurrency] do
          queue[:worker][:concurrency]
        else
          @default_concurrency
        end

      store_rejected_jobs =
        if queue[:worker] && is_boolean(queue[:worker][:store_rejected_jobs]) do
          queue[:worker][:store_rejected_jobs]
        else
          true
        end

      [
        queue: queue[:name],
        concurrency: concurrency,
        store_rejected_jobs: store_rejected_jobs,
        host: queue[:host] || :default
      ]
    end)
  end

  # Checks worker configuration sanity.
  @spec worker_enabled?(keyword) :: boolean
  defp worker_enabled?(queue) do
    case Keyword.get(queue, :worker, []) do
      false ->
        false

      worker ->
        concurrency = Keyword.get(worker, :concurrency, @default_concurrency)

        concurrency > 0
    end
  end

  @spec hosts_config() :: list
  defp hosts_config do
    case Application.fetch_env(:task_bunny, :hosts) do
      {:ok, host_list} -> host_list
      _ -> []
    end
  end

  @doc """
  Returns the list of failure backends.

  It returns `TaskBunny.FailureBackend.Logger` by default.
  """
  @spec failure_backend :: [atom]
  def failure_backend do
    case Application.fetch_env(:task_bunny, :failure_backend) do
      {:ok, list} when is_list(list) -> list
      {:ok, atom} when is_atom(atom) -> [atom]
      _ -> [TaskBunny.FailureBackend.Logger]
    end
  end

  @doc """
  Returns the publisher pool size for poolboy. 15 by default
  """
  @spec publisher_pool_size :: integer
  def publisher_pool_size, do: Application.get_env(:task_bunny, :publisher_pool_size, 15)

  @doc """
  Returns the max overflow for the publisher poolboy. 0 by default
  """
  @spec publisher_max_overflow :: integer
  def publisher_max_overflow, do: Application.get_env(:task_bunny, :publisher_max_overflow, 0)
end
