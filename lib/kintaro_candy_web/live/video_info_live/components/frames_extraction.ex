defmodule KinWeb.VideoInfoLive.FramesExtractionComponent do
  use KinWeb, :live_component
  use Rephex.LiveComponent

  alias Rephex.Selector.CachedSelector
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
    payload = %{params: get_extract_parameter_from_form_params(form_params)}

    {:noreply,
     socket
     |> call_in_root(fn socket -> ExtractFramesAsync.start(socket, payload) end)}

    {:noreply, socket}
  end

  # defp get_extract_parameter_from_form(%Phoenix.HTML.Form{} = extract_form) do
  #   p = extract_form.params

  #   %{
  #     diff_threshold: String.to_integer(p["diff_threshold"]),
  #     stop_frames_length: String.to_integer(p["stop_frames_length"])
  #   }
  # end

  defp get_extract_parameter_from_form_params(params) do
    p = params

    %{
      diff_threshold: String.to_integer(p["diff_threshold"]),
      stop_frames_length: String.to_integer(p["stop_frames_length"])
    }
  end

  defp chart_data(%{} = diff) do
    %{
      chart: %{
        type: "line",
        animations: %{
          enabled: false
        },
        toolbar: %{
          show: true,
          tools: %{
            download: false,
            selection: true,
            zoom: true,
            zoomin: true,
            zoomout: true,
            pan: true,
            reset: true,
            customIcons: []
          }
        }
      },
      series: [
        %{
          name: "diff",
          data: diff |> Enum.sort_by(fn {k, _v} -> k end) |> Enum.map(fn {k, v} -> [k, v] end)
        }
      ],
      xaxis: %{
        type: "numeric"
      }
    }
    |> Jason.encode!()
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
        phx-target={@myself}
        class="border h-full"
      >
        <h2>Step 3. Set Extract parameters</h2>
        <div
          id="diff-chart"
          phx-hook="ApexChartsHook"
          data-chart={chart_data(@rpx.diff_async.result.diff)}
        />
        <.input field={f[:stop_frames_length]} type="number" min="0" label="stop_frames_length" />
        <.input field={f[:diff_threshold]} type="number" min="0" label="diff_threshold" />
        <:actions>
          <.button :if={@rpx.extracted_frames_async.loading != nil} disabled>Extracting ...</.button>
          <.button :if={@rpx.extracted_frames_async.loading == nil}>Extract</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end
end
