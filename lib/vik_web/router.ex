defmodule VikWeb.Router do
  use VikWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {VikWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :basic_auth
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", VikWeb do
    pipe_through :browser

    live "/", DashboardLive, :list
    live "/new", NewLive, :new
    live "/shell", ShellLive, :shell
    live "/log", LogLive, :log
    live "/:slug", ShardLive, :edit
  end

  scope "/api", VikWeb do
    pipe_through :api
    get "/:slug", ShardController, :execute
    post "/:slug", ShardController, :execute
  end

  # Other scopes may use custom stacks.
  # scope "/api", VikWeb do
  #   pipe_through :api
  # end

  defp basic_auth(conn, _opts) do
    username = System.get_env("AUTH_USERNAME", "dummy")
    password = System.get_env("AUTH_PASSWORD", "vikingsarecool")
    Plug.BasicAuth.basic_auth(conn, username: username, password: password)
  end
end
