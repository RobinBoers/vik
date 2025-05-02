defmodule Vik.Webhook do
  @moduledoc """
  Handler for integrating Vik into 3rd-party software
  using (optional) webhooks.

  ## Usage

  To utilize this functionality, export the `WEBHOOK_URL`
  variable in your system's environment:

      export LOGGER_HOOK="https://discord.com/api/webhooks/..."

  """

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
  
  @doc """
  Sends a message to a user-defined webhook.

  The configured endpoint receives JSON data, as defined
  by `t:payload/0`:

      {"event": "shard.save", "content": ... }

  """
  @spec push(event(), term()) :: :ok
  def push(event, data) do
    spawn(fn -> maybe_push(~m{event, content: data}) end)

    :ok
  end

  defp maybe_push(payload) do
    if url = System.get_env("WEBHOOK_URL") do
      Req.post!(url, json: payload)
    end
  end
end