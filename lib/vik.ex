defmodule Vik do
  @moduledoc """
  The public API all Shards have access to; imported
  by default.
  """

  @type slug :: String.t()
  @type export :: module() | {module(), atom(), arity()}

  @doc ~S"""
  Exposes the given function or module as a publicly
  accessible API endpoint.

  ## Examples

      def call(conn, []) do
        send_resp(conn, 200, "hewwo world :3")
      end

      expose call: 2


      def call(conn, ~m{name}s, []) do
        send_resp(conn, 200, "hewwo, #{name}!)
      end

      expose call: 3

  """
  defmacro expose(spec) do
    quote do
      def __call__ do
        unquote(spec)
      end
    end
  end

  @doc """
  Can be used to make modules available to other shards
  using `include/1`.

  ## Examples

      defmodule Hello do
        def world do
          "hewwo world :3"
        end
      end

      export Hello

  """
  defmacro export(module) do
    quote do
      @exports [unquote(module) | @exports]
    end
  end

  @doc """
  Can be used to automatically alias modules
  defined by another shard in the current shard.

  The other module will be compiled before the
  calling module. Cyclic dependencies will crash
  the system. So maybe don't do that? thx :)

  ## Examples

      include "foo"
      Foo.bar()

  """
  defmacro include(slug) do
    # TODO(robin): maybe fix the cyclic dependency issue?

    quote do
      @includes [unquote(slug) | @includes]
    end
  end
end
