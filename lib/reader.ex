defmodule IOx.Reader do
  use GenServer
  alias Types.Point

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @impl true
  def init(opts), do: {:ok, %{algs: Keyword.fetch!(opts, :algs)}, {:continue, :loop}}

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

  defp parse_csv_line(""), do: :skip
  defp parse_csv_line(<<"#", _::binary>>), do: :skip

  defp parse_csv_line(line) do
    case String.split(line, ";", parts: 2) do
      [sx, sy] ->
        with {x, ""} <- Float.parse(sx),
             {y, ""} <- Float.parse(sy) do
          {:ok, %Point{x: x, y: y}}
        else
          _ -> {:error, line}
        end

      _ ->
        {:error, line}
    end
  end
end
