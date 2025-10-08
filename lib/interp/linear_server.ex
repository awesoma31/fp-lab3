defmodule Interp.LinearServer do
  use GenServer
  alias Types.{Point, Sample}
  alias Util.Sampler

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @impl true
  def init(opts) do
    {:ok, %{step: Keyword.fetch!(opts, :step), prev: nil, first?: true}}
  end

  @impl true
  def handle_cast({:point, %Point{} = p}, %{prev: nil} = s) do
    {:noreply, %{s | prev: p}}
  end

  def handle_cast({:point, %Point{} = p1}, %{prev: %Point{} = p0, step: h, first?: first?} = s) do
    m = (p1.y - p0.y) / (p1.x - p0.x)

    Sampler.between(p0.x, p1.x, h, first?)
    |> Stream.each(fn x ->
      y = p0.y + m * (x - p0.x)
      Pipeline.Printer.print(%Sample{x: x, y: y, alg: :linear})
    end)
    |> Stream.run()

    {:noreply, %{s | prev: p1, first?: false}}
  end

  def handle_cast(:eof, s) do
    Pipeline.Printer.flush(:linear)
    {:stop, :normal, s}
  end
end
