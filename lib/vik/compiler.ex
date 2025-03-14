defmodule Vik.Compiler do
  @moduledoc false

  alias Vik.Shard
  alias Vik.Compiled
  alias Vik.Store

  @type slug :: Vik.slug()
  @type source :: String.t()
  @type quoted :: Macro.t()

  @doc """
  Compiles the given `Vik.Shard`.

  Returns the resulting module and any exports. 
  """
  @spec compile(Shard.t()) :: {:ok, term(), [module()]} | {:error, term()}
  def compile(%Shard{} = shard) do
    {result, exports} = compile!(shard)
    {:ok, result, exports}
  rescue
    reason -> {:error, reason}
  end


  @doc """
  Same as `compile/1`, but raises if something crashes
  during compilation.
  """
  @spec compile!(Shard.t()) :: {term(), [module()]}
  def compile!(%Shard{source_code: source} = shard) when is_nil(source) do
    compile!(%Shard{shard | source_code: ""})
  end

  def compile!(%Shard{slug: slug, source_code: source}) do
    exports = extract_exports(slug, source)
    quoted = build_quoted!(slug, source)

    {result, _binding} = Code.eval_quoted(quoted)
    {result, exports}
  end

  @spec build_quoted!(slug(), source()) :: quoted()
  defp build_quoted!(slug, source) when is_binary(source) do
    mod = slug |> module_name() |> Module.concat()
    quoted = Code.string_to_quoted!(source)
    includes = resolve_includes!(source)
    
    quote do
      defmodule unquote(mod) do
        import Vik
        import Plug.Conn

        @exports []
        @includes []

        unquote_splicing(
          for exports <- includes,
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
    includes = extract_includes(source)
    
    for slug <- includes do
      # TODO(robin): deps like this cuase the GenServer to
      # call itself, which then shuts down the entire application
      # for some reason. Oops!
      # %Compiled{} = compiled = Store.ensure_compiled!(slug)
      # compiled.exports
      []
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