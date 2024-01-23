defmodule KinWeb.VideoInfoLive.FramesExtractionComponent do
  alias Rephex.Selector.AsyncSelector
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
      params = FramesExtractionComponent.get_extract_parameter_from_form_params(form_params)

      Kin.Video.extract_keys_when_stopped(diff, params)
    end

    def resolve(_) do
      []
    end
  end

  @type extract_parameter :: Kin.Video.extract_parameter()

  @initial_state %{
    extraction_parameter_form: to_form(%{"diff_threshold" => "10", "stop_frames_length" => "20"}),
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
    payload = %{params: get_extract_parameter_from_form_params(form_params)}

    {:noreply,
     socket
     |> assign(:extraction_parameter_form, to_form(form_params))
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

  def get_extract_parameter_from_form_params(params) do
    p = params

    %{
      diff_threshold: String.to_integer(p["diff_threshold"]),
      stop_frames_length: String.to_integer(p["stop_frames_length"])
    }
  end

  defp chart_data(%{} = diff, keys) do
    window = 5

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
      }
    ]
    |> Jason.encode!(pretty: false)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="frames_extraction">
      <.simple_form
        :let={f}
        :if={@select_should_render.result}
        for={@extraction_parameter_form}
        phx-change="update_extraction_form"
        phx-submit="start_frames_extraction"
        phx-target={@myself}
        class="border h-full m-10"
      >
        <article class="prose">
          <h2>Step 3. Set Extract parameters</h2>
        </article>
        <div
          id="diff-chart"
          phx-hook="PlotlyHook"
          phx-update="ignore"
          data-chart_data={
            chart_data(@rpx.diff_async.result.diff, @select_extracted_keys.async.result)
          }
        />
        <div>Frame count: <%= length(@select_extracted_keys.async.result) %></div>
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
