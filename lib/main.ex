defmodule InterpolationApp.CLI do
  @moduledoc false
  alias Pipeline.Printer

  @usage """
  usage:
    lab_interp [--linear] [--lagrange] [--newton] [--gauss]
               --step <h> [-n <k>] [--precision 6]
  notes:
    input: CSV ';' from stdin, sorted by x
    -n applies to lagrange/newton/gauss (window size), for gauss use odd k.
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
        ]
      )

    h =
      case opts[:step] do
        nil ->
          IO.puts(:stderr, @usage)
          System.halt(2)

        val ->
          val
      end

    n = opts[:n] || 4
    prec = opts[:precision] || 6

    {:ok, _} = Printer.start_link(precision: prec)

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

    if algs == [] do
      IO.puts(:stderr, "choose at least one method")
      System.halt(2)
    end

    {:ok, _rd} = Reader.start_link(algs: algs)
    Process.sleep(:infinity)
  end

  defp maybe_start(list, _name, false, _fun), do: list
  defp maybe_start(list, _name, nil, _fun), do: list

  defp maybe_start(list, _name, true, fun) do
    {:ok, pid} = fun.()
    [pid | list]
  end
end
