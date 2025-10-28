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
