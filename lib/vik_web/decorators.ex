defmodule VikWeb.Decorators do
  @moduledoc """
  This black-magic fuckery allows you to just return the socket
  from LiveView callbacks rather than wrapping it in a tuple like
  `{:noreply, socket}` or `{:ok, socket}`.

  ## Usage

  Put the following at the top of your LiveView to activate this on all
  functions:

      use VikWeb.Decorators
      @decorate_all wrap_noreply()

  If using inside `VikWeb`, this module is automatically activated, and
  only the second line is required.

  ## Circumvention

  If you still wanna return tuples that is fine, and should keep working
  while using this decorator, because for some LiveView behaviour
  (eg. `c:Phoenix.LiveView.handle_info/2`) returning `{:reply, socket, details}`
  tuples is still desired.
  """

  use Decorator.Define, wrap_noreply: 0

  def wrap_noreply(body, context) do
    quote do
      with %Phoenix.LiveView.Socket{} = socket <- unquote(body) do
        callbacks = [:handle_params, :handle_event, :handle_info]

        cond do
          unquote(context.name) == :mount -> {:ok, socket}
          unquote(context.name) in callbacks -> {:noreply, socket}
          true -> socket
        end
      end
    end
  end
end