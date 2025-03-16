defmodule Vik.PubSub do
  @moduledoc false

  def subscribe(topic) do
    Phoenix.PubSub.subscribe(__MODULE__, topic)
  end

  def broadcast(topic, message) do
    Phoenix.PubSub.broadcast(__MODULE__, topic, message)
  end

  def broadcast!(topic, message) do
    Phoenix.PubSub.broadcast!(__MODULE__, topic, message)
  end

  def child_spec(opts \\ []) do
    opts
    |> Keyword.merge(name: __MODULE__)
    |> Phoenix.PubSub.child_spec()
  end
end