defmodule Interp.Window do
  def central_segment(points) do
    xs = Enum.map(points, & &1.x)
    mid = div(length(xs) - 1, 2)
    {Enum.at(xs, mid), Enum.at(xs, mid + 1)}
  end
end
