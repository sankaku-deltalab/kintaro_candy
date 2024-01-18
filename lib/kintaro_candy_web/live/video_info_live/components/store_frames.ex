defmodule KinWeb.VideoInfoLive.StoreFramesComponent do
  use KinWeb, :live_component
  use Rephex.LiveComponent

  alias Rephex.Selector.CachedSelector
  alias KinWeb.State.StoreFramesAsync

  defmodule SelectShouldRender do
    @behaviour CachedSelector.Base

    def args(%{assigns: %{rpx: rpx}} = _socket),
      do: {rpx.video_async, rpx.diff_async, rpx.extracted_frames_async}

    def resolve({video_async, diff_async, extracted_frames_async}) do
      cond do
        extracted_frames_async.loading -> false
        not video_async.ok? -> false
        not diff_async.ok? -> false
        not extracted_frames_async.ok? -> false
        true -> true
      end
    end
  end

  @type extract_parameter :: Kin.Video.extract_parameter()

  @initial_state %{
    output_path_form: to_form(%{"output_directory_path" => ""}),
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
  def handle_event("update_output_form", form_params, socket) do
    {:noreply,
     socket
     |> assign(:output_path_form, to_form(form_params))}
  end

  @impl true
  def handle_event("start_output_frames", form_params, socket) do
    params = %{
      dest_directory: form_params["output_directory_path"]
    }

    {:noreply,
     socket
     |> call_in_root(fn socket -> StoreFramesAsync.start(socket, params) end)}

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        :let={f}
        :if={@select_should_render.result}
        for={@output_path_form}
        phx-change="update_output_form"
        phx-submit="start_output_frames"
        phx-target={@myself}
        class="border h-full"
      >
        <h2>Step 4. Save frames</h2>
        <div class="flex overflow-x-auto">
          <%= for mat <- @rpx.extracted_frames_async.result.frames do %>
            <img class="flex-none" src={Kin.Video.frame_to_base64(mat)} class="w-full" />
          <% end %>
        </div>
        <.input field={f[:output_directory_path]} type="text" label="Save directory" />
        <:actions>
          <.button :if={@rpx.store_frames_async.loading != nil} disabled>Saving ...</.button>
          <.button :if={@rpx.store_frames_async.loading == nil}>Save</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end
end
