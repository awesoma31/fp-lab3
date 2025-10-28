defmodule Pipeline.Sink do
  @moduledoc false

  @callback start_link(keyword) :: GenServer.on_start()
  @callback print(Types.Sample.t()) :: :ok
  @callback flush(atom) :: :ok
end
