defmodule KinWeb.VideoInfoLive.VideoLoadComponent do
  use KinWeb, :live_component
  import Rephex.Component

  alias KinWeb.State.Slice.VideoSlice

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
          phx-submit="start_loading_video"
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

  # defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
