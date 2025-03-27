defmodule Vik.Compiler do
  @moduledoc """
  Compiles the Shards into actual Elixir modules living
  in the Erlang VM.
  """

  alias Vik.Shard
  alias Vik.Compiled
  alias Vik.Thread

  @type slug :: Vik.slug()
  @type source :: String.t()
  @type quoted :: Macro.t()

  @doc """
  Compiles the given `Vik.Shard`.

  Returns the resulting module and any exports. 
  """
  @spec eval(Shard.t()) :: {:ok, term(), [module()], [slug()]} | {:error, term()}
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
          for exports <- dependencies,
              module <- exports do
            quote do
              alias unquote(module)
            end
          end
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

  @spec extract_exports(slug(), source()) :: [module()]
  defp extract_exports(slug, source) when is_binary(slug) and is_binary(source) do
    regex = ~r/export\s+([A-Za-z0-9_.]+)/
    for [_, mod] <- Regex.scan(regex, source) do
      Module.concat(module_name(slug) ++ [mod])
    end
  end
  
  @spec resolve_includes!(source()) :: [[module()]]
  defp resolve_includes!(source) when is_binary(source) do
    source |> extract_includes() |> resolve_includes!()
  end

  @spec resolve_includes!([slug()]) :: [[module()]]
  defp resolve_includes!(includes) when is_list(includes) do    
    for slug <- includes do
      %Compiled{} = compiled = Thread.ensure_compiled!(slug)
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
