defmodule Vik.Compiler do
  @moduledoc """
  Compiles the Shards into actual Elixir modules living
  in the Erlang VM.
  """

  alias Vik.Shard
  alias Vik.Result
  alias Vik.Thread

  @type slug :: Vik.slug()
  @type source :: String.t()
  @type quoted :: Macro.t()

  @doc """
  Compiles the given `Vik.Shard`.

  Returns the resulting module and any exports. 
  """
  @spec eval(Shard.t()) :: {:ok, term(), [Vik.export()], [slug()]} | {:error, term()}
  def eval(%Shard{} = shard) do
    {result, exports, includes} = eval!(shard)
    {:ok, result, exports, includes}
  rescue
    reason -> {:error, reason}
  end

  @doc """
  Same as `eval/1`, but raises if something crashes
  during compilation.
  """
  @spec eval!(Shard.t()) :: {term(), [module()], [slug()]}
  def eval!(%Shard{source_code: source} = shard) when is_nil(source) do
    eval!(%Shard{shard | source_code: ""})
  end

  def eval!(%Shard{slug: slug, source_code: source}) do
    exports = extract_exports(slug, source)
    includes = extract_includes(source)
    quoted = build_quoted!(slug, source, includes)

    Code.put_compiler_option(:ignore_module_conflict, true)

    {result, _binding} = Code.eval_quoted(quoted)
    {result, exports, includes}
  end

  @spec build_quoted!(slug(), source(), [slug()]) :: quoted()
  defp build_quoted!(slug, source, includes) when is_binary(source) do
    mod = slug |> module_name() |> Module.concat()
    dependencies = resolve_includes!(includes)
    quoted = Code.string_to_quoted!(source)

    quote do
      defmodule unquote(mod) do
        import Vik
        import Plug.Conn

        @exports []
        @includes []

        unquote_splicing(
          dependencies
          |> List.flatten()
          |> Enum.group_by(
            fn
              {mod, _fun, _arity} -> mod
              mod when is_atom(mod) -> {:alias, mod}
            end,
            fn
              {_, fun, arity} -> {fun, arity}
              mod when is_atom(mod) -> mod
            end
          )
          |> Enum.flat_map(fn
            {{:alias, mod}, _} ->
              [quote(do: alias(unquote(mod)))]

            {mod, funs} ->
              [quote(do: import(unquote(Module.concat(mod)), only: unquote(funs)))]
          end)
        )

        unquote(quoted)
      end
    end
  end

  @doc """
  Extracts the list of module names that the given
  `Vik.Shard` exports.
  """
  @spec extract_exports(Shard.t()) :: [module()]
  def extract_exports(%Shard{} = shard) do
    extract_exports(shard.slug, shard.source_code)
  end

  @regex ~r/export\s+([A-Za-z0-9_?!]+)(?::\s*(\d+))?/

  @spec extract_exports(slug(), source()) :: [Vik.export()]
  defp extract_exports(slug, source) when is_binary(slug) and is_binary(source) do
    mod = module_name(slug)

    @regex
    |> Regex.scan(source)
    |> Enum.map(fn
      [_, name] -> Module.concat(mod ++ [name])
      [_, name, arity] -> {mod, String.to_atom(name), String.to_integer(arity)}
    end)
  end

  @spec resolve_includes!(source()) :: [[module()]]
  defp resolve_includes!(source) when is_binary(source) do
    source |> extract_includes() |> resolve_includes!()
  end

  @spec resolve_includes!([slug()]) :: [[module()]]
  defp resolve_includes!(includes) when is_list(includes) do
    for slug <- includes do
      %Result{} = compiled = Thread.ensure_compiled!(slug)
      compiled.exports
    end
  end

  @doc """
  Extracts a list of slugs for the shards that
  the given `Vik.Shard` depends on.
  """
  @spec extract_includes(Shard.t()) :: [slug()]
  def extract_includes(%Shard{} = shard) do
    extract_includes(shard.source_code)
  end

  @spec extract_includes(source()) :: [slug()]
  def extract_includes(source) when is_binary(source) do
    regex = ~r/include\s+"([\w-]+)"/
    for [_, slug] <- Regex.scan(regex, source), do: slug
  end

  @doc """
  Generates a module name from a unique slug.
  """
  @spec module_name(slug()) :: module()
  def module_name(slug) do
    ns = slug |> String.replace("-", "_") |> Macro.camelize()
    [Vik, UserShard, ns]
  end
end
