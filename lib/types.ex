defmodule Types do
  @moduledoc false

  defmodule Point do
    @moduledoc false
    defstruct([:x, :y])
  end

  defmodule Sample do
    @moduledoc false
    defstruct([:x, :y, :alg])
  end
end
