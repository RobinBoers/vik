defmodule Vik.System do
  @moduledoc """
  Fetches and formats system information.
  """
  use TypedStruct

  @otp_app :vik
  
  ## Public API

  @doc """
  All connected nodes (including the current node).
  """
  def nodes, do: [node()] ++ Node.list(:connected)

  @doc """
  Fetches system info (version, specs, limits etc.) for
  the given `node`.

  If provided, will fetch values for the given `keys` from
  the shell environment.
  """
  def fetch_system_info(node, keys \\ []) do
    :rpc.call(node, __MODULE__, :info_callback, [keys])
  end

  @doc """
  Fetches current system usage statistics for the given node.
  """
  def fetch_system_usage(node) do
    :rpc.call(node, __MODULE__, :usage_callback, [])
  end

  ## System callbacks

  @doc false
  def info_callback(keys) do
    %{
      versions: %{
        elixir: System.version(),
        phoenix: Application.spec(:phoenix, :vsn) || "None",
        erlang: exact_otp_version(),
        app: Application.spec(@otp_app, :vsn) || "None"
      },
      system_info: %{
        banner: :erlang.system_info(:system_version),
        architecture: :erlang.system_info(:system_architecture)
      },
      system_limits: %{
        atoms: :erlang.system_info(:atom_limit),
        ports: :erlang.system_info(:port_limit),
        processes: :erlang.system_info(:process_limit)
      },
      system_usage: usage_callback(),
      environment: environment(keys)
    }
  end

  defp exact_otp_version do
    [
      :code.root_dir(),
      "releases",
      :erlang.system_info(:otp_release),
      "OTP_VERSION"
    ]
    |> Path.join()
    |> File.read!()
    |> String.trim()
  rescue
    _ -> System.otp_release()
  end

  @doc false
  def usage_callback do
    %{
      io: io(),
      memory: memory(),
      atoms: :erlang.system_info(:atom_count),
      ports: :erlang.system_info(:port_count),
      processes: :erlang.system_info(:process_count),
      uptime: :erlang.statistics(:wall_clock) |> elem(0),
      total_run_queue: :erlang.statistics(:total_run_queue_lengths_all),
      cpu_run_queue: :erlang.statistics(:total_run_queue_lengths)
    }
  end

  defp io do
    {{:input, input}, {:output, output}} = :erlang.statistics(:io)
    {input, output}
  end

  defp memory do
    memory = :erlang.memory()
    total = memory[:total]
    process = memory[:processes]
    atom = memory[:atom]
    binary = memory[:binary]
    code = memory[:code]
    ets = memory[:ets]

    %{
      total: total,
      process: process,
      atom: atom,
      binary: binary,
      code: code,
      ets: ets,
      other: total - process - atom - binary - code - ets
    }
  end

  defp environment(nil), do: nil
  defp environment(keys) do
    Map.new(keys, &{&1, System.get_env(&1)})
  end
end
