defmodule VikWeb.Auth do
  @moduledoc false
  use VikWeb, :plug

  @realm "Vik"

  import Plug.Crypto, only: [secure_compare: 2]
  import Plug.BasicAuth, only: [parse_basic_auth: 1, request_basic_auth: 2]

  def on_mount(:default, _params, session, socket) do
    user = Map.get(session, "current_user")

    {:cont, socket
     |> Phoenix.Component.assign(:current_user, user)
     |> Phoenix.Component.assign(:authenticated?, not is_nil(user))}
  end

  @spec fetch_basic_auth(Plug.Conn.t(), Keyword.t()) :: Plug.Conn.t()
  def fetch_basic_auth(conn, _opts) do
    case validate_credentials(conn) do
      {:ok, username} -> log_in(conn, username)
      :error -> assign(conn, :current_user, nil)
    end
  end
  
  @spec require_auth(Plug.Conn.t(), Keyword.t()) :: Plug.Conn.t()
  def require_auth(conn, _opts) do
    if conn.assigns.current_user do
      conn
    else 
      conn |> request_basic_auth(realm: @realm) |> halt()
    end
  end

  defp validate_credentials(conn) do
    app_password = System.get_env("AUTH_PASSWORD", "vikingsarecool")        

    with {username, password} <- parse_basic_auth(conn) do
      if secure_compare(password, app_password) do
        {:ok, username}
      else
        :error
      end
    end
  end

  defp log_in(conn, username) do
    conn
    |> assign(:current_user, username)
    |> put_session(:current_user, username)
  end
end