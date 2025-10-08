defmodule Interp.LagrangeServer do
  @moduledoc false

  use GenServer
  alias Types.{Point, Sample}
  alias Util.Sampler
  alias Interp.Window

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @impl true
  def init(opts),
    do:
      {:ok,
       %{step: Keyword.fetch!(opts, :step), n: Keyword.fetch!(opts, :n), buf: [], first?: true}}

  @impl true
  def handle_cast({:point, %Point{} = p}, s) do
    buf = [p | s.buf] |> Enum.sort_by(& &1.x) |> Enum.take(-s.n)
    s = %{s | buf: buf}

    if length(buf) == s.n do
      xs = Enum.map(buf, & &1.x)
      ys = Enum.map(buf, & &1.y)
      {a, b} = Window.central_segment(buf)

      Sampler.between(a, b, s.step, s.first?)
      |> Stream.each(fn x ->
        y = lagrange(xs, ys, x)
        Pipeline.Printer.print(%Sample{x: x, y: y, alg: :lagrange})
      end)
      |> Stream.run()

      {:noreply, %{s | first?: false}}
    else
      {:noreply, s}
    end
  end

  def handle_cast(:eof, s) do
    Pipeline.Printer.flush(:lagrange)
    {:stop, :normal, s}
  end

  defp lagrange(xs, ys, x) do
    n = length(xs)

    Enum.reduce(0..(n - 1), 0.0, fn i, acc ->
      li =
        Enum.reduce(0..(n - 1), 1.0, fn j, m ->
          if j == i, do: m, else: m * (x - Enum.at(xs, j)) / (Enum.at(xs, i) - Enum.at(xs, j))
        end)

      acc + Enum.at(ys, i) * li
    end)
  end
end
