defmodule KinWeb.VideoInfoLive.VideoLoadComponent do
  use KinWeb, :live_component
  use Rephex.LiveComponent

  import KinWeb.LiveView.Component

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
    <div id="video_loading">
      <.step_element
        title="Step 1. Select video file"
        form_id="video_loading_form"
        form={@loading_form}
        body_class="w-full"
        loading={@rpx.diff_async.loading != nil}
        phx_change="update_loading_form"
        phx_submit="start_loading_video"
        phx_target={@myself}
      >
        <:form_block :let={f}>
          <.input field={f[:video_path]} type="text" label="Video" />
        </:form_block>
        <:loading_button_block>
          Loading ...
        </:loading_button_block>
        <:submit_button_block>
          Load video
        </:submit_button_block>
      </.step_element>
    </div>
    """
  end
end
