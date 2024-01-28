defmodule KinWeb.VideoInfoLive.DiffCalcComponent do
  use KinWeb, :live_component
  use Rephex.LiveComponent

  import KinWeb.LiveView.Component

  # alias Phoenix.LiveView.Socket
  alias Phoenix.LiveView.AsyncResult
  alias Rephex.Selector.{CachedSelector, AsyncSelector}
  alias KinWeb.State.CalcDiffAsync

  defmodule SelectShouldRender do
    @behaviour CachedSelector.Base

    def args(%{assigns: %{rpx: rpx}} = _socket), do: {rpx.video_async}
    def resolve({video_async}), do: video_async.ok?
  end

  defmodule SelectExampleFrameUri do
    @behaviour CachedSelector.Base

    def args(%{assigns: %{rpx: rpx, diff_parameter_form: form}} = _socket) do
      {rpx.video_async.result, form}
    end

    def resolve({nil, _}), do: ""

    def resolve({%Kin.Video{} = video, form}) do
      frame_idx = String.to_integer(form.params["example_frame_idx"])
      frames = video.example_frames |> Map.keys() |> Enum.sort()
      frame_key = Enum.at(frames, frame_idx, 0)
      params = get_diff_parameter_from_form(form)

      case Kin.Video.get_example_frame_drawn_area(video, frame_key, params) do
        {:ok, diff_frame} -> Kin.Video.frame_to_base64(diff_frame)
        # _ -> exit({:shutdown, :not_found})
        _ -> ""
      end
    end

    defp get_diff_parameter_from_form(%Phoenix.HTML.Form{} = diff_form) do
      p = diff_form.params

      %{
        nw: {String.to_integer(p["area_nw_x"]), String.to_integer(p["area_nw_y"])},
        se: {String.to_integer(p["area_se_x"]), String.to_integer(p["area_se_y"])}
      }
    end
  end

  @initial_state %{
    diff_parameter_form:
      to_form(%{
        "example_frame_idx" => "0",
        "area_nw_x" => "0",
        "area_nw_y" => "0",
        "area_se_x" => "1920",
        "area_se_y" => "1080"
      }),
    select_should_render: CachedSelector.new(SelectShouldRender),
    select_example_frame_uri: AsyncSelector.new(SelectExampleFrameUri, init: "")
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
  def handle_event("update_diff_form", form_params, socket) do
    {:noreply,
     socket
     |> assign(:diff_parameter_form, to_form(form_params))
     |> AsyncSelector.update_selectors_in_socket()}
  end

  @impl true
  def handle_event("start_diff_calculation", params, socket) do
    {:noreply,
     socket
     |> assign(:diff_parameter_form, to_form(params))
     |> AsyncSelector.update_selectors_in_socket()
     |> call_in_root(fn socket ->
       socket
       |> CalcDiffAsync.start(%{
         diff_parameter: get_diff_parameter_from_form(to_form(params))
       })
     end)}
  end

  # defp update_diff_form_by_parameter(
  #        %Phoenix.HTML.Form{} = form,
  #        %{nw: {nw_x, nw_y}, se: {se_x, se_y}} = _diff_parameter
  #      ) do
  #   Map.merge(form.params, %{
  #     "area_nw_x" => nw_x,
  #     "area_nw_y" => nw_y,
  #     "area_se_x" => se_x,
  #     "area_se_y" => se_y
  #   })
  #   |> to_form()
  # end

  defp get_diff_parameter_from_form(%Phoenix.HTML.Form{} = diff_form) do
    p = diff_form.params

    %{
      nw: {String.to_integer(p["area_nw_x"]), String.to_integer(p["area_nw_y"])},
      se: {String.to_integer(p["area_se_x"]), String.to_integer(p["area_se_y"])}
    }
  end

  def video_size_x(video_async), do: video_size(video_async) |> elem(0)
  def video_size_y(video_async), do: video_size(video_async) |> elem(1)

  defp video_size(video_async) do
    case video_async do
      %AsyncResult{ok?: true, result: %Kin.Video{frame_size: frame_size}} ->
        frame_size

      _ ->
        {0, 0}
    end
  end

  def area_input(assigns) do
    ~H"""
    <.input field={@field} phx-debounce="50" type="range" min="0" max={@max} label={@label} />
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="calculating_diff">
      <.step_element
        :if={@select_should_render.result}
        title="Step 2. Set difference parameter"
        form_id="calculating_diff_form"
        form={@diff_parameter_form}
        body_class="w-full max-w-xl"
        loading={@rpx.diff_async.loading != nil}
        phx_change="update_diff_form"
        phx_submit="start_diff_calculation"
        phx_target={@myself}
      >
        <:pre_form>
          <div>
            <img src={@select_example_frame_uri.async.result} class="w-full" />
          </div>
        </:pre_form>
        <:form_block :let={f}>
          <.input
            field={f[:example_frame_idx]}
            phx-debounce="50"
            type="range"
            min="0"
            max={map_size(@rpx.video_async.result.example_frames)}
            label="example frame"
          />
          <.area_input field={f[:area_nw_x]} max={video_size_x(@rpx.video_async)} label="nw.x" />
          <.area_input field={f[:area_se_x]} max={video_size_x(@rpx.video_async)} label="se.x" />
          <.area_input field={f[:area_nw_y]} max={video_size_y(@rpx.video_async)} label="nw.y" />
          <.area_input field={f[:area_se_y]} max={video_size_y(@rpx.video_async)} label="se.y" />
        </:form_block>
        <:loading_button_block>
          Calculating ... <%= "(#{elem(@rpx.diff_async.loading, 0)}/#{elem(@rpx.diff_async.loading, 1)})" %>
        </:loading_button_block>
        <:submit_button_block>
          Calculate diff
        </:submit_button_block>
      </.step_element>
    </div>
    """
  end
end
