defmodule TestHelpers do
  @moduledoc false

  alias Types.Point

  # запускает Printer (1 алгоритм), алг-сервер и прогоняет точки, возвращает stdout строками
  def run_server(mod, opts, points) do
    {:ok, _} = Pipeline.Printer.start_link(precision: 6, total: 1, parent: self())
    {:ok, pid} = mod.start_link(opts)

    Enum.each(points, fn {x, y} ->
      GenServer.cast(pid, {:point, %Types.Point{x: x, y: y}})
    end)

    GenServer.cast(pid, :eof)

    receive do
      :done -> :ok
    after
      2_000 -> raise "timeout waiting :done from Printer"
    end

    # читаем всё, что Printer написал в stdout:
    File.read!("out.log")
  end

  # "alg: 1.500000 2.250000" → {:alg, x, y}
  defp parse_line(line) do
    [alg, sx, sy] =
      Regex.run(~r/^(\w+):\s+([-\d\.]+)\s+([-\d\.]+)$/, line, capture: :all_but_first)

    {String.to_atom(alg), String.to_float(sx), String.to_float(sy)}
  end

  # удобная генерация равномерной таблицы: f.(x) на [a..b] с шагом h
  def make_table(a, b, h, f) do
    a
    |> Stream.iterate(&(&1 + h))
    |> Stream.take_while(&(&1 <= b + 1.0e-12))
    |> Stream.map(&{&1, f.(&1)})
    |> Enum.to_list()
  end
end
