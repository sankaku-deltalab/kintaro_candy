defmodule KinWeb.VideoInfoLive.DiffCalcComponent do
  use KinWeb, :live_component
  import Rephex.Component

  # alias Phoenix.LiveView.Socket
  alias Phoenix.LiveView.AsyncResult
  alias KinWeb.State.Slice.VideoSlice

  @initial_state %{
    diff_parameter_form:
      to_form(%{
        "example_frame_key" => "0",
        "area_nw_x" => "0",
        "area_nw_y" => "0",
        "area_se_x" => "1920",
        "area_se_y" => "1080"
      })
  }

  @impl true
  def update(%{__rephex__: _} = assigns, socket) do
    # TODO: strict form
    {:ok,
     socket
     |> propagate_rephex(assigns)
     #  |> assign(@initial_state)
     |> assign_new(:diff_parameter_form, fn -> @initial_state.diff_parameter_form end)}
  end

  @impl true
  def handle_event("start_redraw_diff_frame", form_params, socket) do
    diff_params = form_params |> to_form() |> get_diff_parameter_from_form()
    frame_key = String.to_integer(form_params["example_frame_key"])

    {:noreply,
     socket
     |> assign(:diff_parameter_form, to_form(form_params))
     |> call_in_root(fn socket ->
       VideoSlice.RedrawFrameForDiffAsync.start(socket, %{
         diff_parameter: diff_params,
         frame_key: frame_key
       })
     end)}
  end

  @impl true
  def handle_event("start_diff_calculation", params, socket) do
    {:noreply,
     socket
     |> assign(:diff_parameter_form, to_form(params))
     |> call_in_root(fn socket ->
       socket
       |> VideoSlice.CalcDiff.start(%{
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

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.slice_component :let={slice} root={@__rephex__} slice={VideoSlice}>
        <.simple_form
          :let={f}
          id="calculating_diff"
          for={@diff_parameter_form}
          phx-change="start_redraw_diff_frame"
          phx-submit="start_diff_calculation"
          phx-target={@myself}
          class="border h-full"
        >
          <h2>Step 2. Set difference parameter</h2>
          <div>
            <div>Video</div>
            <img
              :if={slice.frame_uri_for_diff_async.ok?}
              src={slice.frame_uri_for_diff_async.result}
              class="w-full"
            />
          </div>

          <.input
            field={f[:example_frame_key]}
            phx-throttle="100"
            type="select"
            label="frame key"
            options={slice.video_async.result.example_frames |> Map.keys()}
          />
          <.input
            field={f[:area_nw_x]}
            phx-throttle="100"
            type="range"
            min="0"
            max={video_size_x(slice.video_async)}
            label="nw.x"
          />
          <.input
            field={f[:area_se_x]}
            phx-throttle="100"
            type="range"
            min="0"
            max={video_size_x(slice.video_async)}
            label="se.x"
          />
          <.input
            field={f[:area_nw_y]}
            phx-throttle="100"
            type="range"
            min="0"
            max={video_size_y(slice.video_async)}
            label="nw.y"
          />
          <.input
            field={f[:area_se_y]}
            phx-throttle="100"
            type="range"
            min="0"
            max={video_size_y(slice.video_async)}
            label="se.y"
          />

          <:actions>
            <.button>Calculate diff</.button>
          </:actions>
        </.simple_form>
      </.slice_component>
    </div>
    """
  end
end
