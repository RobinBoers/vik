defmodule Vik.Webhook do
  @moduledoc """
  Handler for integrating Vik into 3rd-party software
  using (optional) webhooks.

  ## Usage

  To utilize this functionality, export the `DEFAULT_WEBHOOK`
  variable in your system's environment:

      export DEFAULT_WEBHOOK="https://discord.com/api/webhooks/..."

  ## Available webhooks

  - `DEFAULT_WEBHOOK` receives messages for *all* events.
  - `LOGGER_WEBHOOK` receives only `logger.message` events.
  - `SCRY_WEBHOOK` receives only `shard.save` events.

  """

  alias Vik.PubSub

  import Structo

  @typedoc """
  Implemented events:

    - `shard.save`
    - `shard.deploy`
    - `logger.message`

  """
  @type event :: binary()

  @typedoc """
  Payload sent to the configured endpoint.
  """
  @type payload :: %{
        event: event(),
        content: term()
      }

  @topic "@webhook/"

  @doc """
  Subscribes the calling process to webhook completion
  notifications.

  Every time a webhook finishes posting, subscribers
  receive `{:webhook, event}`.
  """
  @spec subscribe(String.t()) :: :ok | :error
  def subscribe(topic) when is_binary(topic) do
    PubSub.subscribe(@topic <> topic)
  end

  @doc """
  Sends a message to a user-defined webhook.

  The configured endpoint receives JSON data, as defined
  by `t:payload/0`:

      {"event": "shard.save", "content": ... }

  """
  @spec push(event(), term()) :: :ok
  def push(event, data) do
    case event do
      "logger.message" ->
        async_push(:logger, event, data)
        async_push(:default, event, data)

      "shard.save" ->
        async_push(:scry, event, data)
        async_push(:default, event, data)

      event ->
        async_push(:default, event, data)
    end

    :ok
  end

  defp async_push(scope, event, content) do
    if url = webhook_url(scope) do
      spawn(fn ->
        Req.post!(url, json: ~m{event, content})

        # This introduces a little bit of tight coupling.
        # Ideally, the Webhook module is independent of Shards,
        # however, this makes life a lot easier.
        with %Vik.Shard{slug: topic} <- content do
          PubSub.broadcast(@topic <> topic, {:webhook, event})
        end
      end)
    end
  end

  defp webhook_url(scope) do
    scope
    |> Atom.to_string()
    |> String.upcase()
    |> then(&(&1 <> "_WEBHOOK"))
    |> System.get_env()
  end
end
