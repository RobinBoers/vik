defmodule VikWeb.Router do
  use VikWeb, :router

  import VikWeb.Auth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {VikWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_basic_auth
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", VikWeb do
    pipe_through :browser

    live "/", HomeLive, :landing
  end

  scope "/", VikWeb do
    pipe_through [:browser, :require_auth]

    live "/login", LoginLive, :login
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
end
