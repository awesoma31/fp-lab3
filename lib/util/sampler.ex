defmodule Util.Sampler do
  @moduledoc false
  @eps 1.0e-12

  def between(x0, x1, h, include_left? \\ true) when h > 0 do
    start = if include_left?, do: x0, else: x0 + h
    Stream.unfold(start, fn x -> if x <= x1 + @eps, do: {x, x + h}, else: nil end)
  end
end
