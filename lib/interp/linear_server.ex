defmodule Interp.LinearServer do
  use GenServer

  alias Pipeline.Printer
  alias Types.{Point, Sample}
  alias Util.Sampler

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @impl true
  def init(opts), do: {:ok, %{step: Keyword.fetch!(opts, :step), prev: nil}}

  @impl true
  def handle_cast({:point, %Point{} = p}, %{prev: nil} = s), do: {:noreply, %{s | prev: p}}

  def handle_cast({:point, %Point{} = p1}, %{prev: %Point{} = p0, step: h} = s) do
    m = (p1.y - p0.y) / (p1.x - p0.x)

    Sampler.between(p0.x, p1.x, h)
    |> Stream.each(fn x ->
      Printer.print(%Sample{x: x, y: p0.y + m * (x - p0.x), alg: :linear})
    end)
    |> Stream.run()

    {:noreply, %{s | prev: p1}}
  end

  def handle_cast(:eof, s), do: {:noreply, s}
end
