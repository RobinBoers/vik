defmodule VikWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use VikWeb, :controller
      use VikWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
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

      use Gettext, backend: VikWeb.Gettext

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

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # Translation
      use Gettext, backend: VikWeb.Gettext

      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components
      import VikWeb.CoreComponents

      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS

      # Routes generation with the ~p sigil
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
