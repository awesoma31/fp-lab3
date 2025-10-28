defmodule InterpolationApp.CLI do
  @moduledoc false

  @usage """
  usage:
    lab_interp [--linear] [--lagrange] [--newton] [--gauss]
               --step <h> [-n <k>] [--precision 6]
  """

  def main(argv) do
    {opts, _, _} =
      OptionParser.parse(argv,
        switches: [
          linear: :boolean,
          lagrange: :boolean,
          newton: :boolean,
          gauss: :boolean,
          step: :float,
          n: :integer,
          precision: :integer
        ],
        aliases: [
          l: :linear,
          g: :gauss,
          N: :newton,
          L: :lagrange,
          s: :step,
          n: :n,
          p: :precision
        ]
      )

    h = opts[:step] || abort_usage()
    n = opts[:n] || 4
    prec = opts[:precision] || 6
    alg_count = Enum.count([opts[:linear], opts[:lagrange], opts[:newton], opts[:gauss]], & &1)

    {:ok, _} = Pipeline.SinkRouter.start_link(precision: prec, total: alg_count, parent: self())

    algs =
      []
      |> maybe_start(:linear, opts[:linear], fn -> Interp.LinearServer.start_link(step: h) end)
      |> maybe_start(:lagrange, opts[:lagrange], fn ->
        Interp.LagrangeServer.start_link(step: h, n: n)
      end)
      |> maybe_start(:newton, opts[:newton], fn ->
        Interp.NewtonServer.start_link(step: h, n: n)
      end)
      |> maybe_start(:gauss, opts[:gauss], fn -> Interp.GaussServer.start_link(step: h, n: n) end)

    {:ok, _} = IOx.Reader.start_link(algs: algs)

    receive do
      :done -> :ok
    end
  end

  defp maybe_start(list, _name, true, fun), do: [elem(fun.(), 1) | list]
  defp maybe_start(list, _, _, _), do: list

  defp abort_usage do
    IO.puts(:stderr, @usage)
    System.halt(2)
    exit(2)
  end
end
