defmodule Pipeline.Printer do
  @moduledoc false

  use GenServer
  alias Types.Sample

  @behaviour Pipeline.Sink

  @impl true
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  @impl true
  def print(%Sample{} = s), do: GenServer.cast(__MODULE__, {:sample, s})
  @impl true
  def flush(_alg), do: GenServer.cast(__MODULE__, :flush)

  @impl true
  def init(opts) do
    {:ok,
     %{
       precision: Keyword.get(opts, :precision, 6),
       parent: Keyword.get(opts, :parent, self()),
       total: Keyword.get(opts, :total, 1),
       done: 0
     }}
  end

  @impl true
  def handle_cast({:sample, %{x: x, y: y, alg: alg}}, s) do
    fx = :erlang.float_to_binary(x, decimals: s.precision)
    fy = :erlang.float_to_binary(y, decimals: s.precision)
    IO.puts("#{alg}: #{fx} #{fy}")
    {:noreply, s}
  end

  @impl true
  def handle_cast({:flush, _alg}, s) do
    new_done = s.done + 1
    if new_done >= s.total, do: send(s.parent, :done)
    {:noreply, %{s | done: new_done}}
  end
end
