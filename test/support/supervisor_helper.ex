defmodule TaskBunny.SupervisorHelper do
  @moduledoc false

  def start_taskbunny(passed_in_opts \\ []) do
    return =
      [name: TaskBunny.Supervisor, publisher: false, workers: []]
      |> Keyword.merge(passed_in_opts)
      |> TaskBunny.Supervisor.start_link()

    Process.sleep(20)
    return
  end

  def tear_down do
    case Process.whereis(TaskBunny.Supervisor) do
      nil -> nil
      pid -> Process.exit(pid, :brutal_kill)
    end

    Process.sleep(200)

    :ok
  end
end
