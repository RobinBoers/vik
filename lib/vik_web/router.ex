defmodule VikWeb.Router do
  @moduledoc false
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

  scope "/api", VikWeb do
    pipe_through :api

    get "/:slug", ShardController, :single
    post "/:slug", ShardController, :single
    get "/:group/:shard", ShardController, :group
    post "/:group/:shard", ShardController, :group
  end

  scope "/", VikWeb do
    pipe_through [:browser, :require_auth]

    live "/login", LoginLive, :login
    live "/new", NewLive, :new
    live "/shell", ShellLive, :shell
    live "/log", LogLive, :log
    live "/:slug", ShardLive, :edit
  end
end
