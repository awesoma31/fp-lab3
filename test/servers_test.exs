defmodule Lab3.ServersTest do
  use ExUnit.Case, async: false
  alias Types.Point

  setup do
    {:ok, _} = Process.whereis(Test.MemorySink) || Test.MemorySink.start_link([])
    Test.MemorySink.clear()
    :ok
  end

  defp approx(a, b, eps \\ 1.0e-6), do: abs(a - b) <= eps

  defp wait_until(fun, timeout \\ 200) do
    start = System.monotonic_time(:millisecond)

    Stream.repeatedly(fn -> fun.() end)
    |> Enum.reduce_while(nil, fn ok, _ ->
      cond do
        ok ->
          {:halt, :ok}

        System.monotonic_time(:millisecond) - start > timeout ->
          {:halt, :timeout}

        true ->
          Process.sleep(5)
          {:cont, nil}
      end
    end)
  end

  test "LinearServer: y=x, step=0.7" do
    {:ok, pid} = Interp.LinearServer.start_link(step: 0.7)

    for {x, y} <- [{0.0, 0.0}, {1.0, 1.0}, {2.0, 2.0}, {3.0, 3.0}] do
      GenServer.cast(pid, {:point, %Point{x: x, y: y}})
    end

    GenServer.cast(pid, :eof)
    assert :ok == wait_until(fn -> Test.MemorySink.flush_count(:linear) == 1 end)

    samples = Test.MemorySink.samples()
    assert Enum.all?(samples, &(&1.alg == :linear and approx(&1.x, &1.y)))
    assert Test.MemorySink.flush_count(:linear) == 1
  end

  test "NewtonServer: y=x, n=4, step=0.5" do
    {:ok, pid} = Interp.NewtonServer.start_link(step: 0.5, n: 4)
    for i <- 0..6, do: GenServer.cast(pid, {:point, %Point{x: i * 1.0, y: i * 1.0}})
    GenServer.cast(pid, :eof)
    assert :ok == wait_until(fn -> Test.MemorySink.flush_count(:newton) == 1 end)

    samples = Test.MemorySink.samples()
    assert Enum.all?(samples, &(&1.alg == :newton and approx(&1.x, &1.y, 1.0e-5)))
    assert Test.MemorySink.flush_count(:newton) == 1
  end

  test "GaussServer: равномерные узлы y=x, n=5, step=0.5" do
    {:ok, pid} = Interp.GaussServer.start_link(step: 0.5, n: 5)
    for i <- 1..8, do: GenServer.cast(pid, {:point, %Point{x: i * 1.0, y: i * 1.0}})
    GenServer.cast(pid, :eof)

    assert :ok == wait_until(fn -> Test.MemorySink.flush_count(:gauss) == 1 end)

    samples = Test.MemorySink.samples()
    assert Enum.all?(samples, &(&1.alg == :gauss and approx(&1.x, &1.y, 1.0e-4)))
    assert Test.MemorySink.flush_count(:gauss) == 1
  end
end
