defmodule TaskBunny.JobTest do
  use ExUnit.Case, async: false
  import TaskBunny.QueueTestHelper
  alias TaskBunny.{JobTestHelper.TestJob, Queue, Message, QueueTestHelper}

  setup_all do
    {:ok, _pid} =
      TaskBunny.SupervisorHelper.start_taskbunny(
        publisher: {:publisher, [TestJob]},
        workers: [TestJob]
      )

    on_exit(fn -> TaskBunny.SupervisorHelper.tear_down() end)
    :ok
  end

  setup do
    clean(Queue.queue_with_subqueues(TestJob.queue_name()))
    Queue.declare_with_subqueues(:default, TestJob.queue_name())

    :ok
  end

  describe "enqueue" do
    test "enqueues job" do
      payload = %{"foo" => "bar"}
      :ok = TestJob.enqueue(payload, queue: TestJob.queue_name())

      {received, _} = QueueTestHelper.pop(TestJob.queue_name())
      {:ok, %{"payload" => received_payload}} = Message.decode(received)
      assert received_payload == payload
    end

    test "returns an error for wrong option" do
      payload = %{"foo" => "bar"}

      assert {:error, _} =
               TestJob.enqueue(
                 payload,
                 queue: TestJob.queue_name(),
                 host: :invalid_host
               )
    end
  end

  describe "enqueue!" do
    test "raises an exception for a wrong host" do
      payload = %{"foo" => "bar"}

      assert_raise TaskBunny.Publisher.PublishError, fn ->
        TestJob.enqueue!(payload, queue: TestJob.queue_name(), host: :invalid_host)
      end
    end
  end
end
