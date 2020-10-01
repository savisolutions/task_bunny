defmodule TaskBunny do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  # use Application

  alias TaskBunny.Status

  def register_metrics do
    if Code.ensure_loaded(Wobserver) == {:module, Wobserver} do
      Wobserver.register(:page, {"Task Bunny", :taskbunny, &Status.page/0})
      Wobserver.register(:metric, [&Status.metrics/0])
    end
  end
end
