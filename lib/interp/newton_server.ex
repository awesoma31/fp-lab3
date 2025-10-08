defmodule Interp.NewtonServer do
  use GenServer

  alias Types.{Point, Sample}
  alias Util.Sampler
  alias Interp.Window

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @impl true
  def init(opts),
    do: {:ok, %{step: Keyword.fetch!(opts, :step), n: Keyword.fetch!(opts, :n), buf: []}}

  @impl true
  def handle_cast({:point, %Point{} = p}, s) do
    buf = [p | s.buf] |> Enum.sort_by(& &1.x) |> Enum.take(-s.n)
    s = %{s | buf: buf}

    if length(buf) == s.n do
      xs = Enum.map(buf, & &1.x)
      ys = Enum.map(buf, & &1.y)
      coeffs = divided_diffs(xs, ys)
      {a, b} = Window.central_segment(buf)

      Sampler.between(a, b, s.step)
      |> Stream.each(fn x ->
        y = horner_newton(xs, coeffs, x)
        Pipeline.Printer.print(%Sample{x: x, y: y, alg: :newton})
      end)
      |> Stream.run()
    end

    {:noreply, s}
  end

  def handle_cast(:eof, s), do: {:noreply, s}

  defp divided_diffs(xs, ys) do
    n = length(xs)
    do_dd(xs, ys, 0, n, [])
  end

  defp do_dd(_xs, _col, k, n, acc) when k == n,
    do: Enum.reverse(acc)

  defp do_dd(xs, col, k, n, acc) do
    # a_k = col[0]
    coeffs_acc = [hd(col) | acc]

    next_col =
      col
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.with_index()
      |> Enum.map(fn {[y0, y1], i} ->
        # Δ^{k+1} y_i = (y1 - y0) / (x_{i+1+k} - x_i)
        (y1 - y0) / (Enum.at(xs, i + 1 + k) - Enum.at(xs, i))
      end)

    do_dd(xs, next_col, k + 1, n, coeffs_acc)
  end

  defp horner_newton(xs, coeffs, x) do
    Enum.with_index(coeffs)
    |> Enum.reduce(0.0, fn {a_k, k}, acc ->
      mul =
        if k == 0,
          do: 1.0,
          else: Enum.reduce(0..(k - 1), 1.0, fn j, m -> m * (x - Enum.at(xs, j)) end)

      acc + a_k * mul
    end)
  end
end
