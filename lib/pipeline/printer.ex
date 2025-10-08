defmodule Pipeline.Printer do
  use GenServer

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(opts), do: {:ok, %{precision: Keyword.get(opts, :precision, 6)}}
  def print(%Types.Sample{} = s), do: GenServer.cast(__MODULE__, {:sample, s})

  @impl true
  def handle_cast({:sample, %{x: x, y: y, alg: alg}}, s) do
    fx = :erlang.float_to_binary(x, decimals: s.precision)
    fy = :erlang.float_to_binary(y, decimals: s.precision)
    IO.puts("#{alg}: #{fx} #{fy}")
    {:noreply, s}
  end
end
