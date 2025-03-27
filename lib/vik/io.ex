defmodule Vik.IO do
  @moduledoc false

  alias Vik.PubSub

  @default_opts [
    capture_prompt: true,
    encoding: :unicode,
    input: ""
  ]

  def capture(fun, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)
    {input, opts} = Keyword.pop(opts, :input)

    original_io = Process.group_leader()
    original_err = Process.whereis(:standard_error)

    {:ok, capture_io} = StringIO.open(input, opts)
    {:ok, capture_err} = StringIO.open("", opts)

    try do
      Process.group_leader(self(), capture_io)
      Process.unregister(:standard_error)
      Process.register(capture_err, :standard_error)
  
      result = fun.()

      {_, stdout} = StringIO.contents(capture_io)
      {_, stderr} = StringIO.contents(capture_err)

      {result, stdout, stderr}
    after
      Process.group_leader(self(), original_io)
      Process.unregister(:standard_error)
      Process.register(original_err, :standard_error)

      StringIO.close(capture_io)
      StringIO.close(capture_err)
    end
  end
end
