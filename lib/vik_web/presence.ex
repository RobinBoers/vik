defmodule Vik.Presence do
  @moduledoc """
  Enables live awareness features in collaborative contexts.
  """
  use Phoenix.Presence,
    otp_app: :vik,
    pubsub_server: Vik.PubSub

  alias Vik.PubSub
  alias Vik.Authority

  @topic "@presence/" # Topic used for communication with API users.
  @prefix Authority.topic() # Channel/room topic on which Presence runs.

  @doc """
  Subscribes to room join/leaves.

  ## Message format

  - `{:join, suid, ~m{id, name, metas}}`
  - `{:leave, suid, ~m{id, name, metas}}`

  """
  @spec subscribe(Authority.suid()) :: :ok | :error
  def subscribe(suid) when is_binary(suid) do
    PubSub.subscribe(@topic <> suid)
  end
  
  @doc """
  Unsubscribes from room join/leaves.
  """
  @spec subscribe(Authority.suid()) :: :ok | :error
  def unsubscribe(suid) when is_binary(suid) do
    PubSub.unsubscribe(@topic <> suid)
  end

  @doc """
  Returns a list of all active participants in a session.
  """
  @spec list_participants(Authority.suid()) :: :ok | :error
  def list_participants(suid) when is_binary(suid) do
    @prefix <> suid |> fetch(list(@prefix <> suid)) |> Map.values()
  end

  @doc """
  Counts the amount of active participants in a session.
  """
  @spec count_participants(Authority.suid()) :: :ok | :error
  def count_participants(suid) when is_binary(suid) do
    @prefix <> suid |> list() |> map_size()
  end

  @doc false
  @impl true
  def init(_opts) do
    {:ok, Map.new()}
  end

  @doc false
  @impl true
  def fetch(@prefix <> _suid, presences) do
    for {uid, presence} <- presences, into: %{} do
      {uid, Map.merge(presence, %{id: uid, name: uid})}
    end
  end

  @doc false
  @impl true
  def handle_metas(@prefix <> suid, %{joins: joins, leaves: leaves}, presences, state) do
    for {uid, presence} <- joins do
      data = %{id: uid, name: presence.name, metas: Map.fetch!(presences, uid)}
      PubSub.broadcast(@topic <> suid, {:join, suid, data})
    end

    for {uid, presence} <- leaves do
      data = %{id: uid, name: presence.name, metas: Map.get(presences, uid, [])}
      PubSub.broadcast(@topic <> suid, {:leave, suid, data})
    end

    {:ok, state}
  end
end
