defmodule VikWeb do
  @moduledoc """
  Web Layer for the Editor backend.
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end
  
  def plug do
    quote do
      import Plug.Conn
      import Phoenix.Controller
      
      unquote(verified_routes())
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: VikWeb.Layouts]

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {VikWeb.Layouts, :app}

      alias Phoenix.LiveView.Socket

      import VikWeb,
        only: [
          stream_color: 4,
          stream_lines: 2,
          stream_lines: 3
        ]

      # Allows you to return just socket instead of
      # needing to wrap in {:noreply, socket} tuple.
      use VikWeb.Decorators
      
      unquote(html_helpers())
    end
  end

  def live_hook do
    quote do
      import Phoenix.LiveView
      import Phoenix.Component

      alias Phoenix.LiveView.Socket

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      import Phoenix.HTML
      import VikWeb.CoreComponents

      alias Phoenix.LiveView.JS

      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: VikWeb.Endpoint,
        router: VikWeb.Router,
        statics: VikWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end

  # Helpers used in terminal components. Should probably be moved later.
  # But ehhh, y'know... if it works, don't touch it.

  def stream_color(socket, assign, lines, color) do
    lines = Enum.map(lines, &{:safe, "<span class='#{color}'>#{&1}</span>"})
    Phoenix.LiveView.stream(socket, assign, lines)
  end

  def stream_lines(socket, assign, initial_lines \\ []) do
    socket
    |> Phoenix.LiveView.stream_configure(assign, dom_id: &dom_id/1)
    |> Phoenix.LiveView.stream(assign, initial_lines)
  end

  defp dom_id(_) do
    :crypto.strong_rand_bytes(8) |> Base.encode16()
  end
end
