defmodule Pipeline.SinkRouter do
  def sink_mod, do: Application.get_env(:lab3, :sink, Pipeline.Printer)
  def start_link(opts), do: sink_mod().start_link(opts)
  def print(sample), do: sink_mod().print(sample)
  def flush(alg), do: sink_mod().flush(alg)
end
