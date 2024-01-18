defmodule KinWeb.VideoInfoLive.VideoLoadComponent do
  use KinWeb, :live_component
  use Rephex.LiveComponent

  alias KinWeb.State.LoadVideoAsync
  alias Phoenix.LiveView.Socket

  @initial_state %{
    loading_form: to_form(%{"video_path" => ""})
  }

  @impl true
  def mount(socket) do
    {:ok, socket |> assign(@initial_state)}
  end

  @impl true
  def update(%{rpx: _} = assigns, socket) do
    {:ok, socket |> propagate_rephex(assigns)}
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
       LoadVideoAsync.start(socket, %{video_path: video_path})
     end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
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
    </div>
    """
  end
end
