defmodule Vik.Mailer do
  @moduledoc """
  SMTP mailer for sending emails with Markdown content.
  """
  
  @mime_boundary "frontier"

  require Logger

  def deliver(body, opts \\ []) do
    from = Keyword.get(opts, :from, System.fetch_env!("SMTP_SENDER"))
    to = Keyword.get(opts, :to, [System.fetch_env!("SMTP_USERNAME")])

    deliver(from, to, opts[:subject], body)
  end

  def deliver(from, to, subject, body) do
    headers = build_headers(from, to, subject)
    body = build_mime(headers, body)
    relay_opts = build_relay_opts()

    case :gen_smtp_client.send({from, List.wrap(to), body}, relay_opts) do
      {:ok, _receipt} -> Logger.info("Sent from #{from} to #{inspect(to)}")
      {:error, reason} -> raise "Delivery error: #{inspect(reason)}"
    end
  end

  defp build_headers(from, to, subject) do
    [
      {"From", from},
      {"To", to |> List.wrap() |> Enum.join(", ")},
      subject && {"Subject", subject},
      {"MIME-Version", "1.0"},
      {"Content-Type", ~s<multipart/alternative; boundary="#{@mime_boundary}">}
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp build_mime(headers, body) do
    headers
    |> Enum.map(fn {key, value} -> "#{key}: #{value}" end)
    |> Enum.concat([build_multipart(body)])
    |> Enum.join("\r\n")
  end

  defp build_multipart(body) do
    """
    --#{@mime_boundary}
    Content-Type: text/plain; charset=UTF-8
    Content-Transfer-Encoding: 7bit

    #{to_plain(body)}

    --#{@mime_boundary}
    Content-Type: text/html; charset=UTF-8
    Content-Transfer-Encoding: 7bit

    #{to_html(body)}

    --#{@mime_boundary}--
    """
  end

  defp to_plain(markdown) do
    markdown
    |> String.replace(~r/\*\*(.*?)\*\*/, "\\1")
    |> String.replace(~r/\*(.*?)\*/, "\\1")
    |> String.replace(~r/`(.*?)`/, "\\1")
    |> String.replace(~r/\#{1,6}\s*(.*)/, "\\1")
    |> String.replace(~r/\[([^\]]+)\]\([^)]+\)/, "\\1")
  end

  defp to_html(markdown) do
    Earmark.as_html!(markdown)
  end

  defp build_relay_opts do    
    base_opts = [
      {:hostname, str_env("SMTP_HOST")},
      {:port, int_env("SMTP_PORT")},
      {:username, str_env("SMTP_USERNAME")},
      {:password, str_env("SMTP_PASSWORD")}
    ]

    cond do
      bool_env("SMTP_SSL") -> Keyword.put(base_opts, :ssl, true)
      bool_env("SMTP_TLS") -> Keyword.put(base_opts, :tls, :always)
      true -> base_opts
    end
  end
  
  # Helpers for parsing configuration from application environment
  defp str_env(var), do: var |> System.fetch_env!() |> String.to_charlist()
  defp int_env(var), do: var |> System.fetch_env!() |> String.to_integer()
  defp bool_env(var), do: System.get_env(var, "false") == "true"
end