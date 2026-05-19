defmodule Vik.Scry do
  @moduledoc """
  API client for [Scry](https://github.com/dupunkto/scry), the version control
  system used to track shard revisions.

  ## Usage

  - `SCRY_ENDPOINT`: the API root of a Scry instance. For example:
    `"https://scry.dupunkto.org"`.

  - `SCRY_SECRET`: the secret to authenticate API requests and
    webhook calls.

  If neither of these variables is configured, Scry functionality will be
  disabled. See `enabled?/0`.
  """

  require Logger

  @type history :: %{
          revisions: [revision()],
          pending: non_neg_integer()
        }

  @type revision :: %{
          sha: String.t(),
          message: String.t(),
          timestamp: integer()
        }

  defp base_url, do: Application.get_env(:vik, :scry, [])[:endpoint]
  defp secret, do: Application.get_env(:vik, :scry, [])[:secret]

  @doc """
  Returns whether Scry functionality is enabled.
  """
  @spec enabled?() :: boolean()
  def enabled? do
    not is_nil(base_url()) and not is_nil(secret())
  end

  @doc """
  Generates a public URL to a revision `sha`.
  """
  @spec revision_url(String.t()) :: String.t() | nil
  def revision_url(sha) when is_binary(sha) do
    if base_url = base_url() do
      "#{base_url}/rev/#{sha}"
    end
  end

  @doc """
  Generates a public URL to an `object`.
  """
  @spec object_url(String.t()) :: String.t() | nil
  def object_url(object) when is_binary(object) do
    if base_url = base_url() do
      "#{base_url}/object/#{URI.encode(object)}"
    end
  end

  @doc """
  Fetch revision history for `object` from Scry.
  """
  @spec history(String.t()) :: history() | nil
  def history(object) when is_binary(object) do
    base_url = base_url()
    secret = secret()

    if base_url && secret do
      url = "#{base_url}/api/history/#{URI.encode(object, &URI.char_unreserved?/1)}"

      case Req.get(url, params: [token: secret]) do
        {:ok, %Req.Response{status: 200, body: body}} ->
          %{"revisions" => revisions, "pending" => pending} = body

          revisions =
            Enum.map(revisions, fn revision ->
              %{
                sha: revision["sha"],
                message: revision["message"],
                timestamp: revision["timestamp"]
              }
            end)

          %{revisions: revisions, pending: pending}

        _ ->
          nil
      end
    end
  end

  @doc """
  Tracks a new edit to `object` with content `source`.
  """
  @spec track(String.t(), String.t()) :: :ok | {:error, term()}
  def track(object, source) when is_binary(object) and is_binary(source) do
    base_url = base_url()
    secret = secret()

    if base_url && secret do
      url = "#{base_url}/api/track/#{URI.encode(object, &URI.char_unreserved?/1)}"

      case Req.post(url, params: [token: secret], form: [source_code: source]) do
        {:ok, %Req.Response{status: 200}} -> :ok
        {:ok, %Req.Response{} = response} -> {:error, response}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, :not_configured}
    end
  end

  @doc """
  Squashes all pending edits for `object` into a single revision
  with description `message`.
  """
  @spec squash(String.t(), String.t()) :: :ok | {:error, term()}
  def squash(object, message) when is_binary(object) and is_binary(message) do
    base_url = base_url()
    secret = secret()

    if base_url && secret do
      url = "#{base_url}/api/squash/#{URI.encode(object, &URI.char_unreserved?/1)}"

      case Req.post(url, params: [token: secret], form: [message: message]) do
        {:ok, %Req.Response{status: 200}} ->
          :ok

        {:ok, %Req.Response{} = response} ->
          {:error, response}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :not_configured}
    end
  end
end
