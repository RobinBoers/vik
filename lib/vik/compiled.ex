defmodule Vik.Compiled do
  @moduledoc """
  Structural representation of a compiled shard.
  """
  use TypedStruct

  import Structo

  typedstruct do
    field :module, module()
    field :result, term()
    field :exports, [module()]

    # If a newer version of the module is
    # available in the database, but failed to
    # compile.
    field :stale?, boolean(), default: false
  end

  @spec new(term(), [module()]) :: t()
  def new(result, exports) do
    {:module, module, _, _} = result
    ~m{:__MODULE__, module, result, exports}
  end

  @spec put_stale(t()) :: t()
  def put_stale(%__MODULE__{} = c, yes? \\ true) do
    %__MODULE__{c | stale?: yes?}
  end
end