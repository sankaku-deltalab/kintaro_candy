defmodule KinWeb.VideoInfoLive.FramesExtractionComponent do
  use KinWeb, :live_component
  import Rephex.LiveComponent

  # alias KinWeb.State.ExtractFramesAsync

  @initial_state %{
    extraction_parameter_form: to_form(%{"diff_threshold" => "10", "stop_frames_length" => "20"})
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
  def handle_event("update_extraction_form", _form_params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("start_frames_extraction", _form_params, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        :let={f}
        for={@extraction_parameter_form}
        phx-change="update_extraction_form"
        phx-submit="start_frames_extraction"
        class="border h-full"
      >
        <h2>Step 3. Set Extract parameters</h2>
        <.input field={f[:stop_frames_length]} type="number" min="0" label="stop_frames_length" />
        <.input field={f[:diff_threshold]} type="number" min="0" label="diff_threshold" />
        <:actions>
          <.button>Extract frames</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end
end
