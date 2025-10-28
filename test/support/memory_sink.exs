defmodule Test.MemorySink do
  @behaviour Pipeline.Sink
  use GenServer
  alias Types.Sample

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  def init(:ok), do: {:ok, %{samples: [], flushes: %{}}}

  @impl true
  def print(%Sample{} = s), do: GenServer.cast(__MODULE__, {:print, s})
  :ok
  @impl true
  def flush(alg), do: GenServer.cast(__MODULE__, {:flush, alg})
  :ok

  # helpers для тестов
  def samples, do: GenServer.call(__MODULE__, :samples)
  def flush_count(alg), do: GenServer.call(__MODULE__, {:flush_count, alg})
  def clear, do: GenServer.call(__MODULE__, :clear)

  def handle_cast({:print, s}, st), do: {:noreply, %{st | samples: [s | st.samples]}}

  def handle_cast({:flush, alg}, st) do
    {:noreply, %{st | flushes: Map.update(st.flushes, alg, 1, &(&1 + 1))}}
  end

  def handle_call(:samples, _f, st), do: {:reply, Enum.reverse(st.samples), st}
  def handle_call({:flush_count, alg}, _f, st), do: {:reply, Map.get(st.flushes, alg, 0), st}
  def handle_call(:clear, _f, _st), do: {:reply, :ok, %{samples: [], flushes: %{}}}
end
