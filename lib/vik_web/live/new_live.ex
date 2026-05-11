defmodule VikWeb.NewLive do
  @moduledoc false
  use VikWeb, :live_view

  alias Vik.Repo
  alias Vik.Shard
  alias Vik.PubSub

  on_mount VikWeb.Auth
  on_mount {VikWeb.SystemHandler, :static}

  @impl true
  def mount(_params, _session, socket) do
    form = %{} |> Shard.new_changeset() |> to_form()
    {:ok, assign(socket, form: form)}
  end

  @impl true
  def handle_event("validate", %{"shard" => params}, socket) do
    form = params |> Shard.new_changeset() |> to_form(action: :validate)
    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("create", %{"shard" => params}, socket) do
    case params |> Shard.new_changeset() |> Repo.insert() do
      {:ok, %Shard{} = shard} ->
        PubSub.broadcast("vik:dashboard", {:new, shard})
        {:noreply, push_navigate(socket, to: ~p"/#{shard.slug}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main>
      <hgroup>
        <h1>Create a new shard</h1>
        <p>A shard is a snippet of Elixir source code that can be exposed as a plug.</p>
      </hgroup>

      <.form for={@form} phx-change="validate" phx-submit="create">
        <.input type="text" field={@form[:title]} label="Title" />
        <.input type="text" field={@form[:slug]} label="Slug" />
        <.input type="hidden" field={@form[:source_code]} />

        <.button phx-disable-with="Creating...">Create shard</.button>
      </.form>
    </main>
    """
  end
end
