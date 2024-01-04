defmodule KinWeb.VideoInfoLive.VideoLoadComponent do
  use KinWeb, :live_component
  import Rephex.Component

  alias KinWeb.State.Slice.VideoSlice
  alias Phoenix.LiveView.Socket

  @initial_state %{
    loading_form: to_form(%{"video_path" => ""})
  }

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.slice_component :let={_slice} root={@__rephex__} slice={VideoSlice}>
        <.simple_form
          :let={f}
          for={@loading_form}
          phx-change="update_loading_form"
          phx-submit="start_loading_video"
          phx-target={@myself}
          class="border h-full"
        >
          <h2>Step 1. Select video file</h2>
          <.input field={f[:video_path]} type="text" label="Video" />
          <:actions>
            <.button>Load video</.button>
          </:actions>
        </.simple_form>
      </.slice_component>
    </div>
    """
  end

  @impl true
  def update(%{__rephex__: _} = assigns, socket) do
    {:ok,
     socket
     |> propagate_rephex(assigns)
     |> assign(@initial_state)}
  end

  @impl true
  def handle_event("update_loading_form", _params, %Socket{} = socket) do
    # TODO: validate path

    {:noreply, socket}
  end

  @impl true
  def handle_event("start_loading_video", %{"video_path" => video_path}, %Socket{} = socket) do
    {:noreply,
     socket
     |> call_in_root(fn socket ->
       VideoSlice.LoadVideoAsync.start(socket, %{video_path: video_path})
     end)}
  end

  # defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
