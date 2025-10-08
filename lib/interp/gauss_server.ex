defmodule Interp.GaussServer do
  use GenServer

  alias Types.Sample
  alias Util.Sampler
  alias Interp.Window

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)
  @impl true
  def init(opts),
    do: {:ok, %{step: Keyword.fetch!(opts, :step), n: Keyword.fetch!(opts, :n), buf: []}}

  @impl true
  def handle_cast({:point, p}, s) do
    buf = [p | s.buf] |> Enum.sort_by(& &1.x) |> Enum.take(-s.n)
    s = %{s | buf: buf}

    if length(buf) == s.n and rem(s.n, 2) == 1 do
      xs = Enum.map(buf, & &1.x)
      h = Enum.chunk_every(xs, 2, 1, :discard) |> Enum.map(fn [a, b] -> b - a end)
      uniform? = Enum.max(h) - Enum.min(h) < 1.0e-9

      if uniform? do
        ys = Enum.map(buf, & &1.y)
        mid = div(s.n - 1, 2)
        x0 = Enum.at(xs, mid)
        h0 = Enum.at(xs, mid + 1) - x0
        diff = diff_table(ys)
        {a, b} = Window.central_segment(buf)

        Sampler.between(a, b, s.step)
        |> Stream.each(fn x ->
          p = (x - x0) / h0
          y = gauss_central(p, diff, mid)
          Pipeline.Printer.print(%Sample{x: x, y: y, alg: :gauss})
        end)
        |> Stream.run()
      end
    end

    {:noreply, s}
  end

  def handle_cast(:eof, s), do: {:noreply, s}

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

  # Формула Гаусса (центральная), суммирование по k
  defp gauss_central(p, diff, mid) do
    # diff = [Δ^0 y, Δ^1 y, Δ^2 y, ...]; для чёт/нечёт разные индексы
    Enum.with_index(diff)
    |> Enum.reduce(0.0, fn {row, k}, acc ->
      term =
        case k do
          0 ->
            Enum.at(row, mid)

          # нечётные: Δ^1 y_{mid-1}, Δ^3 y_{mid-2}, ...
          k when rem(k, 2) == 1 ->
            idx = mid - div(k + 1, 2)
            poly = falling(p, k)
            poly * Enum.at(row, idx) / fact(k)

          # чётные: Δ^2 y_{mid-1}, Δ^4 y_{mid-2}, ...
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
