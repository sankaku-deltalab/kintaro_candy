defmodule KinWeb.VideoInfoLive.FramesExtractionComponent do
  use KinWeb, :live_component
  import Rephex.LiveComponent

  alias Rephex.CachedSelector
  alias KinWeb.State.ExtractFramesAsync

  defmodule SelectShouldRender do
    @behaviour CachedSelector.Base

    def args(%{assigns: %{rpx: rpx}} = _socket), do: {rpx.video_async, rpx.diff_async}

    def resolve({video_async, diff_async}) do
      cond do
        diff_async.loading -> false
        not video_async.ok? or not diff_async.ok? -> false
        true -> true
      end
    end
  end

  @type extract_parameter :: Kin.Video.extract_parameter()

  @initial_state %{
    extraction_parameter_form: to_form(%{"diff_threshold" => "10", "stop_frames_length" => "20"}),
    select_should_render: CachedSelector.new(SelectShouldRender)
  }

  @impl true
  def mount(socket) do
    {:ok, socket |> assign(@initial_state)}
  end

  @impl true
  def update(%{rpx: _} = assigns, socket) do
    {:ok,
     socket
     |> propagate_rephex(assigns)
     |> CachedSelector.update_selectors_in_socket()}
  end

  @impl true
  def handle_event("update_extraction_form", form_params, socket) do
    {:noreply,
     socket
     |> assign(:extraction_parameter_form, to_form(form_params))}
  end

  @impl true
  def handle_event("start_frames_extraction", form_params, socket) do
    params = get_extract_parameter_from_form(form_params)

    {:noreply,
     socket
     |> call_in_root(fn socket -> ExtractFramesAsync.start(socket, params) end)}

    {:noreply, socket}
  end

  defp get_extract_parameter_from_form(%Phoenix.HTML.Form{} = diff_form) do
    p = diff_form.params

    %{
      diff_threshold: String.to_integer(p["diff_threshold"]),
      stop_frames_length: String.to_integer(p["stop_frames_length"])
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        :let={f}
        :if={@select_should_render.result}
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
