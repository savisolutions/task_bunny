defmodule TaskBunny.ConfigTest do
  use ExUnit.Case, async: false
  alias TaskBunny.Config

  defp test_config, do: [queue: [namespace: "test."]]

  setup_all do
    {:ok, _pid} = TaskBunny.SupervisorHelper.start_taskbunny()
    on_exit(fn -> TaskBunny.SupervisorHelper.tear_down() end)
    :ok
  end

  setup do
    :meck.new(Application, [:passthrough])
    :meck.expect(Application, :get_all_env, fn :task_bunny -> test_config() end)

    on_exit(fn -> :meck.unload() end)

    :ok
  end

  describe "publisher_pool_size" do
    test "returns the pool size for the publisher if it has been configured for the application" do
      :meck.expect(Application, :get_env, fn :task_bunny, :publisher_pool_size, 15 -> 5 end)

      assert Config.publisher_pool_size() == 5
    end

    test "returns 15 by default" do
      assert Config.publisher_pool_size() == 15
    end
  end

  describe "publisher_max_overflow" do
    test "returns the max overflow for the publisher if is configured for the application" do
      :meck.expect(Application, :get_env, fn :task_bunny, :publisher_max_overflow, 0 -> 5 end)

      assert Config.publisher_max_overflow() == 5
    end

    test "returns 0 by default" do
      assert Config.publisher_max_overflow() == 0
    end
  end
end
