defmodule Types do
  defmodule Point, do: defstruct([:x, :y])
  defmodule Sample, do: defstruct([:x, :y, :alg])
end
