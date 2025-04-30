defmodule VikWeb.LoginLive do
  @moduledoc false
  use VikWeb, :live_view

  # This LiveView exists purely to be able to trigger logins from the
  # non-authenticated homepage.

  @impl true
  def mount(_params, _session, socket) do
    {:ok, push_navigate(socket, to: ~p"/")}
  end
end
