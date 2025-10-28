# ЛР 3 Elixir

- Студент: `Чураков Александр Алексеевич`
- Группа: `P3331`

---

Описание задания - [task.md](./task.md)

## 🔹 Ключевые элементы реализации

- **Архитектура на процессах (GenServer):**
  - `IOx.Reader` — читает точки из `stdin`, парсит `x;y`, рассылает всем активным алгоритмам.
    ```elixir
    # lib/reader.ex

    @impl true
    def handle_continue(:loop, s) do
      case IO.gets("") do
        :eof ->
          Enum.each(s.algs, &GenServer.cast(&1, :eof))
          {:noreply, s}

        {:error, reason} ->
          IO.puts(:stderr, "stdin error: #{inspect(reason)}")
          {:noreply, s, {:continue, :loop}}

        line when is_binary(line) ->
          case parse_csv_line(String.trim(line)) do
            {:ok, p} -> Enum.each(s.algs, &GenServer.cast(&1, {:point, p}))
            :skip -> :ok
            {:error, l} -> IO.puts(:stderr, "parse error: #{l}")
          end

          {:noreply, s, {:continue, :loop}}
      end
    end
    ```
  - `Interp.*Server` (`Linear`, `Newton`, `Lagrange`, `Gauss`) — реализуют интерполяцию по скользящему окну.
    ```elixir
    defmodule Interp.LinearServer do
      @moduledoc false

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
          Pipeline.SinkRouter.print(%Sample{x: x, y: y, alg: :linear})
        end)
        |> Stream.run()

        {:noreply, %{s | prev: p1, first?: false}}
      end

      def handle_cast(:eof, s) do
        Pipeline.SinkRouter.flush(:linear)
        {:stop, :normal, s}
      end
    end
    ```
  - `Pipeline.SinkRouter` — маршрутизатор вывода.
    ```elixir
    defmodule Pipeline.SinkRouter do
      @moduledoc false

      def sink_mod, do: Application.get_env(:lab3, :sink, Pipeline.Printer)
      def start_link(opts), do: sink_mod().start_link(opts)
      def print(sample), do: sink_mod().print(sample)
      def flush(alg), do: sink_mod().flush(alg)
    end
    ```
  - `Pipeline.Printer` — поток вывода в `stdout`, форматирует числа с заданной точностью.
    ```elixir
    defmodule Pipeline.Printer do
      @moduledoc false

      use GenServer
      alias Types.Sample

      @behaviour Pipeline.Sink

      @impl true
      def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
      @impl true
      def print(%Sample{} = s), do: GenServer.cast(__MODULE__, {:sample, s})
      @impl true
      def flush(_alg), do: GenServer.cast(__MODULE__, :flush)

      @impl true
      def init(opts) do
        {:ok,
        %{
          precision: Keyword.get(opts, :precision, 6),
          parent: Keyword.get(opts, :parent, self()),
          total: Keyword.get(opts, :total, 1),
          done: 0
        }}
      end

      @impl true
      def handle_cast({:sample, %{x: x, y: y, alg: alg}}, s) do
        fx = :erlang.float_to_binary(x, decimals: s.precision)
        fy = :erlang.float_to_binary(y, decimals: s.precision)
        IO.puts("#{alg}: #{fx} #{fy}")
        {:noreply, s}
      end

      @impl true
      def handle_cast({:flush, _alg}, s) do
        new_done = s.done + 1
        if new_done >= s.total, do: send(s.parent, :done)
        {:noreply, %{s | done: new_done}}
      end
    end
    ```

- **Интерполяционные методы:**
  - Линейная: вычисление по отрезкам через угловой коэффициент.
  - Ньютон: разделённые разности, построение полинома n-й степени.
  - Лагранж: прямая формула Лагранжа для текущего окна.
  - Гаусс: центральные разности с проверкой равномерности узлов.

- **Управление через CLI:**
  ```
  usage:
    lab_interp [--linear] [--lagrange] [--newton] [--gauss]
               --step <h> [-n <k>] [--precision 6]
  ```

  ```bash
  ./out/interpolation_app --linear --step 0.7 < data.csv
  ./out/interpolation_app --newton -n 4 --step 0.5 < data.csv
  ./out/interpolation_app --gauss -n 5 --step 0.5 < data.csv
  ```


## Ввод и вывод программы

**Пример ввода (`stdin`):**

```
# x;y 
0;0
1;1
2;2
3;3
4;4
5;5
7;7
8;8

```

**Пример вывода (`stdout`):**

`% ./out/interpolation_app  --newton --lagrange -n 4 --step 0.5 < data/example.csv`


```
newton: 1.000000 1.000000
newton: 1.500000 1.500000
newton: 2.000000 2.000000
lagrange: 1.000000 1.000000
lagrange: 1.500000 1.500000
lagrange: 2.000000 2.000000
lagrange: 2.500000 2.500000
lagrange: 3.000000 3.000000
newton: 2.500000 2.500000
newton: 3.000000 3.000000
newton: 3.500000 3.500000
newton: 4.000000 4.000000
newton: 4.500000 4.500000
newton: 5.000000 5.000000
lagrange: 3.500000 3.500000
lagrange: 4.000000 4.000000
lagrange: 4.500000 4.500000
lagrange: 5.000000 5.000000
newton: 5.500000 5.500000
newton: 6.000000 6.000000
newton: 6.500000 6.500000
newton: 7.000000 7.000000
lagrange: 5.500000 5.500000
lagrange: 6.000000 6.000000
lagrange: 6.500000 6.500000
lagrange: 7.000000 7.000000
```

## Тесты

```elixir
defmodule Lab3.ServersCorrectnessTest do
  use ExUnit.Case, async: false
  alias Types.Point
  @eps 1.0e-6

  setup do
    unless Process.whereis(Test.MemorySink), do: Test.MemorySink.start_link([])
    Test.MemorySink.clear()
    :ok
  end

  defp wait_until(fun, timeout \\ 200) do
    deadline = System.monotonic_time(:millisecond) + timeout

    Stream.repeatedly(fn -> fun.() end)
    |> Enum.reduce_while(nil, fn ok, _ ->
      cond do
        ok ->
          {:halt, :ok}

        System.monotonic_time(:millisecond) >= deadline ->
          {:halt, :timeout}

        true ->
          Process.sleep(5)
          {:cont, nil}
      end
    end)
  end

  test "LinearServer: f(x)=2x+3, step=0.5" do
    f = fn x -> 2.0 * x + 3.0 end
    {:ok, pid} = Interp.LinearServer.start_link(step: 0.5)

    for x <- [0.0, 1.0, 2.0, 3.0] do
      GenServer.cast(pid, {:point, %Point{x: x, y: f.(x)}})
    end

    GenServer.cast(pid, :eof)

    assert :ok == wait_until(fn -> Test.MemorySink.flush_count(:linear) == 1 end)

    samples =
      Test.MemorySink.samples()
      |> Enum.filter(&(&1.alg == :linear))

    for s <- samples do
      assert_in_delta s.y, f.(s.x), @eps
    end
  end

  test "NewtonServer: f(x)=x^3, n=4, step=0.5" do
    f = fn x -> x * x * x end
    {:ok, pid} = Interp.NewtonServer.start_link(step: 0.5, n: 4)

    for x <- 0..5 do
      GenServer.cast(pid, {:point, %Point{x: x * 1.0, y: f.(x * 1.0)}})
    end

    GenServer.cast(pid, :eof)

    assert :ok == wait_until(fn -> Test.MemorySink.flush_count(:newton) == 1 end)

    samples =
      Test.MemorySink.samples()
      |> Enum.filter(&(&1.alg == :newton))

    for s <- samples do
      assert_in_delta s.y, f.(s.x), 1.0e-5
    end
  end

  test "LagrangeServer: f(x)=x^3, n=4, step=0.25 — точное совпадение" do
    f = fn x -> x * x * x end
    {:ok, pid} = Interp.LagrangeServer.start_link(step: 0.25, n: 4)

    for x <- 0..5 do
      GenServer.cast(pid, {:point, %Point{x: x * 1.0, y: f.(x * 1.0)}})
    end

    GenServer.cast(pid, :eof)

    assert :ok == wait_until(fn -> Test.MemorySink.flush_count(:lagrange) == 1 end)

    samples =
      Test.MemorySink.samples()
      |> Enum.filter(&(&1.alg == :lagrange))

    for s <- samples do
      assert_in_delta s.y, f.(s.x), 1.0e-5
    end
  end

  test "GaussServer: равномерные узлы, n=5, f(x)=x — точное; f(x)=x^2 — малые погрешности" do
    {:ok, pid} = Interp.GaussServer.start_link(step: 0.5, n: 5)

    f1 = fn x -> x end
    f2 = fn x -> x * x end

    for x <- 0..8, do: GenServer.cast(pid, {:point, %Point{x: x * 1.0, y: f1.(x * 1.0)}})
    for x <- 10..18, do: GenServer.cast(pid, {:point, %Point{x: x * 1.0, y: f2.(x * 1.0)}})

    GenServer.cast(pid, :eof)
    assert :ok == wait_until(fn -> Test.MemorySink.flush_count(:gauss) == 1 end)

    samples = Test.MemorySink.samples() |> Enum.filter(&(&1.alg == :gauss))

    {s1, s2} = Enum.split_with(samples, &(&1.x <= 8.5))

    for s <- s1, do: assert_in_delta(s.y, f1.(s.x), 1.0e-6)
    for s <- s2, do: assert_in_delta(s.y, f2.(s.x), 2)
  end
end
```

## Выводы

В работе реализована потоковая архитектура на Elixir, где каждая часть — отдельный процесс:

- Чтение, вычисление и вывод изолированы, что упрощает тестирование и масштабирование.
- Подход с `GenServer` демонстрирует силу акторной модели и удобство обработки асинхронных данных. Но усложняется тестирование и может появляться необходимость создавать точки синхронизации. 
