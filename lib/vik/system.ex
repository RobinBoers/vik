defmodule Vik.System do
  @moduledoc """
  Fetches and formats system information.

  Most logic is straight up stolen from `Phoenix.LiveDashboard`.
  Sowwy not sowwy.
  """
  use TypedStruct

  typedstruct module: ProcessDetails do
    @moduledoc false

    field :pid, pid()
    field :name_or_initial_call, term()
    field :initial_call, term()
  end

  typedstruct module: PortDetails do
    @moduledoc false

    field :port, Port.t()
    field :description, String.t()
  end

  ## Public API

  def fetch_system_info(node, keys \\ [], app \\ :vik) do
    :rpc.call(node, __MODULE__, :info_callback, [keys, app])
  end

  def fetch_system_usage(node) do
    :rpc.call(node, __MODULE__, :usage_callback, [])
  end

  ## System callbacks

  @doc false
  def info_callback(keys, app) do
    %{
      versions: %{
        elixir: System.version(),
        phoenix: Application.spec(:phoenix, :vsn) || "None",
        erlang: exact_otp_version(),
        app: Application.spec(app, :vsn) || "None"
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

  ## Constructors

  def pid_or_port_details(pid) when is_pid(pid), do: to_process_details(pid)
  def pid_or_port_details(name) when is_atom(name), do: to_process_details(name)
  def pid_or_port_details(port) when is_port(port), do: to_port_details(port)
  def pid_or_port_details(reference) when is_reference(reference), do: reference

  def to_process_details(pid) when is_pid(pid) and node(pid) == node() do
    {name, initial_call} = resolve_process_details(pid)
    %ProcessDetails{pid: pid, name_or_initial_call: name, initial_call: initial_call}
  end

  def to_process_details(pid) when is_pid(pid) do
    %ProcessDetails{pid: pid, name_or_initial_call: nil, initial_call: nil}
  end

  def to_process_details(name) when is_atom(name) do
    name |> Process.whereis() |> to_process_details()
  end

  def to_port_details(port) when is_port(port) do
    description =
      case Port.info(port, :name) do
        {:name, name} -> name
        _ -> port
      end

    %PortDetails{port: port, description: description}
  end

  defp resolve_process_details(pid) when is_pid(pid) do
    case Process.info(pid, [:initial_call, :dictionary, :registered_name]) do
      [{:initial_call, initial_call}, {:dictionary, dictionary}, {:registered_name, name}] ->
        initial_call = Keyword.get(dictionary, :"$initial_call", initial_call)

        name =
          format_registered_name(name) ||
            format_process_label(Keyword.get(dictionary, :"$process_label")) ||
            format_initial_call(initial_call)

        {name, initial_call}

      _ ->
        {nil, nil}
    end
  end

  ## Formatting helpers

  defp format_process_label(nil), do: nil
  defp format_process_label(label) when is_binary(label), do: label
  defp format_process_label(label), do: inspect(label)

  defp format_registered_name([]), do: nil
  defp format_registered_name(name), do: inspect(name)

  defp format_initial_call({:supervisor, mod, arity}), do: Exception.format_mfa(mod, :init, arity)
  defp format_initial_call({m, f, a}), do: Exception.format_mfa(m, f, a)
  defp format_initial_call(nil), do: nil

  @doc """
  All connected nodes (including the current node).
  """
  def nodes(), do: [node()] ++ Node.list(:connected)
end
