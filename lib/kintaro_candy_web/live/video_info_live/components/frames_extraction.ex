defmodule KinWeb.VideoInfoLive.FramesExtractionComponent do
  alias Rephex.Selector.AsyncSelector
  use KinWeb, :live_component
  use Rephex.LiveComponent

  import KinWeb.LiveView.Component

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

  defmodule SelectExtractedKeys do
    @behaviour CachedSelector.Base

    alias KinWeb.VideoInfoLive.FramesExtractionComponent

    def args(%{assigns: %{rpx: rpx, extraction_parameter_form: form}} = _socket) do
      diff =
        if rpx.diff_async.ok? do
          rpx.diff_async.result.diff
        else
          nil
        end

      {diff, form.params}
    end

    def resolve({%{} = diff, form_params}) do
      with {:ok, params} <-
             FramesExtractionComponent.get_extract_parameter_from_form_params(form_params) do
        Kin.Video.extract_keys_when_stopped(diff, params)
      else
        _ -> []
      end
    end

    def resolve(_) do
      []
    end
  end

  @type extract_parameter :: Kin.Video.extract_parameter()

  @initial_state %{
    extraction_parameter_form:
      to_form(%{"diff_threshold" => "100", "stop_frames_length" => "20"}),
    select_should_render: CachedSelector.new(SelectShouldRender),
    select_extracted_keys: AsyncSelector.new(SelectExtractedKeys, init: [])
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
     |> CachedSelector.update_selectors_in_socket()
     |> AsyncSelector.update_selectors_in_socket()}
  end

  @impl true
  def handle_event("update_extraction_form", form_params, socket) do
    {:noreply,
     socket
     |> assign(:extraction_parameter_form, to_form(form_params))
     |> AsyncSelector.update_selectors_in_socket()}
  end

  @impl true
  def handle_event("start_frames_extraction", form_params, socket) do
    with {:ok, params} <- get_extract_parameter_from_form_params(form_params) do
      payload = %{params: params}

      {:noreply,
       socket
       |> assign(:extraction_parameter_form, to_form(form_params))
       |> call_in_root(fn socket -> ExtractFramesAsync.start(socket, payload) end)}

      {:noreply, socket}
    else
      _ -> {:noreply, socket}
    end
  end

  # defp get_extract_parameter_from_form(%Phoenix.HTML.Form{} = extract_form) do
  #   p = extract_form.params

  #   %{
  #     diff_threshold: String.to_integer(p["diff_threshold"]),
  #     stop_frames_length: String.to_integer(p["stop_frames_length"])
  #   }
  # end

  def get_extract_parameter_from_form_params(params) do
    p = params

    with {diff_threshold, _} <- Integer.parse(p["diff_threshold"]),
         {stop_frames_length, _} <- Integer.parse(p["stop_frames_length"]) do
      {:ok, %{diff_threshold: diff_threshold / 100, stop_frames_length: stop_frames_length}}
    else
      _ -> {:error, "invalid parameter"}
    end
  end

  defp chart_data(%{} = diff, form_params, keys) do
    window = 1

    diff_series_items =
      diff
      |> Enum.sort_by(fn {k, _v} -> k end)
      |> Stream.chunk_every(window, window, :discard)
      |> Stream.map(&Enum.sort_by(&1, fn {_k, v} -> v end, :desc))
      |> Stream.map(&hd/1)
      |> Stream.map(fn {k, v} -> {k, Float.round(v * 100)} end)
      |> Enum.to_list()

    diff_series_xs = diff_series_items |> Enum.map(fn {x, _y} -> x end)
    diff_series_ys = diff_series_items |> Enum.map(fn {_x, y} -> y end)

    keys_series_items = keys |> Enum.sort() |> Enum.map(fn k -> {k, 0} end)
    keys_series_xs = keys_series_items |> Enum.map(fn {x, _y} -> x end)
    keys_series_ys = keys_series_items |> Enum.map(fn {_x, y} -> y end)

    diff_threshold =
      case get_extract_parameter_from_form_params(form_params) do
        {:ok, %{diff_threshold: diff_threshold}} -> diff_threshold
        _ -> 0
      end

    diff_threshold = diff_threshold * 100
    threshold_xs = [List.first(diff_series_xs), List.last(diff_series_xs)]
    threshold_ys = [diff_threshold, diff_threshold]

    [
      %{
        name: "diff",
        mode: "line",
        x: diff_series_xs,
        y: diff_series_ys
      },
      %{
        name: "extract_key",
        mode: "markers",
        x: keys_series_xs,
        y: keys_series_ys
      },
      %{
        name: "threshold",
        mode: "line",
        x: threshold_xs,
        y: threshold_ys
      }
    ]
    |> Jason.encode!(pretty: false)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="frames_extraction">
      <.step_element
        :if={@select_should_render.result}
        title="Step 3. Set Extract parameters"
        form_id="frames_extraction_form"
        form={@extraction_parameter_form}
        body_class="w-full"
        loading={@rpx.extracted_frames_async.loading != nil}
        phx_change="update_extraction_form"
        phx_submit="start_frames_extraction"
        phx_target={@myself}
      >
        <:pre_form>
          <div
            id="diff-chart"
            phx-hook="PlotlyHook"
            phx-update="ignore"
            data-chart_data={
              chart_data(
                @rpx.diff_async.result.diff,
                @extraction_parameter_form.params,
                @select_extracted_keys.async.result
              )
            }
          />
          <div>Frame count: <%= length(@select_extracted_keys.async.result) %></div>
        </:pre_form>
        <:form_block :let={f}>
          <.input
            field={f[:diff_threshold]}
            type="number"
            min="0"
            phx-debounce="50"
            label="diff_threshold"
          />
          <.input
            field={f[:stop_frames_length]}
            type="number"
            min="0"
            phx-debounce="50"
            label="stop_frames_length"
          />
        </:form_block>
        <:loading_button_block>Extracting ...</:loading_button_block>
        <:submit_button_block>Extract</:submit_button_block>
      </.step_element>
    </div>
    """
  end
end
