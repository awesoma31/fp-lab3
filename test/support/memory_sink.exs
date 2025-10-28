defmodule Test.MemorySink do
  @behaviour Pipeline.Sink
  use GenServer
  alias Types.Sample

  @impl true
  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def samples, do: GenServer.call(__MODULE__, :samples)
  def flush_count(alg), do: GenServer.call(__MODULE__, {:fc, alg})
  def clear, do: GenServer.call(__MODULE__, :clear)

  @impl true
  def print(%Sample{} = s), do: GenServer.cast(__MODULE__, {:print, s})

  @impl true
  def flush(alg), do: GenServer.cast(__MODULE__, {:flush, alg})

  @impl true
  def init(:ok), do: {:ok, %{samples: [], flushes: %{}}}

  @impl true
  def handle_cast({:print, s}, st), do: {:noreply, %{st | samples: [s | st.samples]}}

  @impl true
  def handle_cast({:flush, a}, st),
    do: {:noreply, %{st | flushes: Map.update(st.flushes, a, 1, &(&1 + 1))}}

  @impl true
  def handle_call(:samples, _from, st), do: {:reply, Enum.reverse(st.samples), st}

  @impl true
  def handle_call({:fc, a}, _from, st), do: {:reply, Map.get(st.flushes, a, 0), st}

  @impl true
  def handle_call(:clear, _from, _st), do: {:reply, :ok, %{samples: [], flushes: %{}}}
end
