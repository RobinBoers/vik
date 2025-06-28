defmodule Vik.Result do
  @moduledoc """
  Structural representation of a compiled `Vik.Shard`.
  Holds metadata regarding compile-dependencies, along
  with the compilation result.

  The `stale?` flag indicates that a newer version of
  the module exists in the database but failed to compile.

  This data is recorded in the `Vik.Store`.
  """
  use TypedStruct

  import Structo

  typedstruct do
    field :module, module()
    field :result, term()
    field :exports, [Vik.export()]
    field :includes, [Vik.slug()]

    # If a newer version of the module is
    # available in the database, but failed to
    # compile.
    field :stale?, boolean(), default: false
  end

  @spec new(term(), [module()], [Vik.slug()]) :: t()
  def new(result, exports, includes) do
    {:module, module, _, _} = result
    ~m{:__MODULE__, module, result, exports, includes}
  end

  @spec put_stale(t()) :: t()
  def put_stale(%__MODULE__{} = c, yes? \\ true) do
    %__MODULE__{c | stale?: yes?}
  end
end
