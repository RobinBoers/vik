defmodule VikWeb.CodeMirror do
  @moduledoc """
  Fully-fledged CodeMirror editor with support for
  optional collaborative editing.
  """
  use VikWeb, :live_component

  alias Vik.Authority
  alias Vik.Authority.Update

  import Structo

  attr :id, :string
  attr :name, :string
  attr :value, :string
  attr :field, Phoenix.FormField
  attr :suid, :string, default: nil
  attr :uid, :string, default: nil

  attr :rest, :global

  @doc """
  Renders a CodeMirror instance as a drop-in replacement
  for a HTML textarea.

  This component provides feature-parity with
  `CoreComponents.input/1`.
  """
  def codemirror(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> codemirror()
  end

  def codemirror(assigns) do
    ~H"""
    <%= if @suid do %>
      <.live_component module={__MODULE__} {assigns} />
    <% else %>
      <.render {assigns} />
    <% end %>
    """
  end

  @doc """
  Applies the provided `Vik.Authority.Update`s to
  the CodeMirror instance with the given ID.
  """
  def sync(id, updates) do
    send_update(VikWeb.CodeMirror, ~m{id, updates})
  end
  
  @impl true
  def update(~m{updates}, socket) do
    {:ok, push_event(socket, "collab:pull", %{changes: updates})}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("collab:fetch", ~m{version}s, socket) do
    suid = socket.assigns.suid
    {:reply, %{changes: Authority.fetch_changes(suid, version)}, socket}
  end

  @impl true
  def handle_event("collab:push", ~m{version, updates}s, socket) do
    suid = socket.assigns.suid
    updates = deserialize_changes(updates)
    {:reply, %{status: Authority.push_changes(suid, version, updates)}, socket}
  end

  @impl true
  def handle_event("collab:doc", _params, socket) do
    suid = socket.assigns.suid
    {:reply, Authority.get_document(suid), socket}
  end

  defp deserialize_changes(updates) do
    Enum.map(updates, &%Update{
      client_id: &1["clientID"],
      changes: &1["changes"],
      effects: &1["effects"]
    })
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id={"#{@id}-wrapper"}
      phx-hook="CodeMirror"
      class="codemirror"
      data-suid={@suid}
      data-uid={@uid}
    >
      <div
        id={"#{@id}-target"}
        class="target"
        phx-update="ignore"
      ></div>
      <textarea
        id={@id}
        name={@name}
        data-update-ignore="hidden"
        {@rest}
      >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
    </div>
    """
  end
end
