defmodule Interp.GaussServer do
  @moduledoc false

  use GenServer
  alias Types.Point

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

    if length(buf) == s.n and rem(s.n, 2) == 1 do
      xs = Enum.map(buf, & &1.x)
      ys = Enum.map(buf, & &1.y)

      hvals = xs |> Enum.chunk_every(2, 1, :discard) |> Enum.map(fn [a, b] -> b - a end)
      tol = 1.0e-6

      if Enum.max(hvals) - Enum.min(hvals) >= tol do
        IO.puts(
          :stderr,
          "[gauss] non-uniform window skipped: " <>
            Enum.map_join(hvals, ", ", &Float.round(&1, 6))
        )

        {:noreply, %{s | first?: false}}
      else
        mid = div(s.n - 1, 2)
        x0 = Enum.at(xs, mid)
        # средний шаг
        h0 = Enum.sum(hvals) / max(length(hvals), 1)
        diff = diff_table(ys)
        {a, b} = Interp.Window.central_segment(buf)

        Util.Sampler.between(a, b, s.step, s.first?)
        |> Stream.each(fn x ->
          p1 = (x - x0) / h0
          y = gauss_central(p1, diff, mid)
          Pipeline.SinkRouter.print(%Types.Sample{x: x, y: y, alg: :gauss})
        end)
        |> Stream.run()

        {:noreply, %{s | first?: false}}
      end
    else
      {:noreply, s}
    end
  end

  def handle_cast(:eof, s) do
    Pipeline.SinkRouter.flush(:gauss)
    {:stop, :normal, s}
  end

  defp diff_table(ys) do
    n = length(ys)
    rows = [ys]

    Enum.reduce(1..(n - 1), rows, fn _k, acc ->
      prev = hd(acc)
      next = Enum.chunk_every(prev, 2, 1, :discard) |> Enum.map(fn [a, b] -> b - a end)
      [next | acc]
    end)
    |> Enum.reverse()
  end

  defp gauss_central(p, diff, mid) do
    Enum.with_index(diff)
    |> Enum.reduce(0.0, fn {row, k}, acc ->
      term =
        case k do
          0 ->
            Enum.at(row, mid)

          k when rem(k, 2) == 1 ->
            idx = mid - div(k + 1, 2)
            poly = falling(p, k)
            poly * Enum.at(row, idx) / fact(k)

          _ ->
            idx = mid - div(k, 2)
            poly = falling(p, k)
            poly * Enum.at(row, idx) / fact(k)
        end

      acc + term
    end)
  end

  defp falling(p, k), do: Enum.reduce(0..(k - 1), 1.0, fn i, acc -> acc * (p - i) end)
  defp fact(k), do: Enum.reduce(1..max(k, 1), 1, &*/2)
end
