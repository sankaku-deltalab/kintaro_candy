# defmodule KinWeb.VideoInfoLive.State2 do
#   import Phoenix.Component
#   import Phoenix.LiveView

#   alias Phoenix.LiveView.AsyncResult
#   alias Phoenix.LiveView.Socket

#   @initial_state %{
#     loading_form: to_form(%{"video_path" => ""}),
#     diff_parameter_form:
#       to_form(%{
#         "area_nw_x" => "0",
#         "area_nw_y" => "0",
#         "area_se_x" => "0",
#         "area_se_y" => "0"
#       }),
#     extract_parameter_form: to_form(%{"diff_threshold" => "10", "stop_frames_length" => "20"}),
#     output_path_form: to_form(%{"output_directory_path" => ""}),
#     video_async: %AsyncResult{},
#     diff_async: %AsyncResult{},
#     extracted_frames_async: %AsyncResult{}
#   }

#   def init(socket) do
#     socket =
#       socket
#       |> assign(@initial_state)

#     {:ok, socket}
#   end

#   # Video loading
#   def update_loading_form(params, %Socket{} = socket) do
#     socket = socket |> assign(:loading_form, to_form(params))

#     {:noreply, socket}
#   end

#   def request_loading_video(%{"video_path" => video_path} = _params, %Socket{} = socket) do
#     socket =
#       socket
#       |> assign(:video_async, AsyncResult.loading(socket.assigns.video_async))
#       |> start_async(:video_was_loaded, fn ->
#         {:ok, video} = Kin.Video.load_video(video_path)
#         video
#       end)

#     {:noreply, socket}
#   end

#   def video_was_loaded({:ok, %Kin.Video{} = video} = _result, %Socket{} = socket) do
#     old_video_async = socket.assigns.video_async

#     socket =
#       socket
#       |> assign(:video_async, AsyncResult.ok(old_video_async, video))
#       |> assign(:diff_parameter_form, diff_parameter_to_form(%{nw: {0, 0}, se: video.frame_size}))

#     {:noreply, socket}
#   end

#   def video_was_loaded({:exit, reason} = _result, %Socket{} = socket) do
#     old_video_async = socket.assigns.video_async

#     socket =
#       socket
#       |> assign(:video_async, AsyncResult.failed(old_video_async, {:error, reason}))
#       |> put_flash(:error, "Failed to load video")

#     {:noreply, socket}
#   end

#   # Diff calculation
#   def update_diff_form(params, %Socket{} = socket) do
#     socket = socket |> assign(:diff_parameter_form, to_form(params))

#     {:noreply, socket}
#   end

#   def request_calculating_diff(params, %Socket{} = socket) do
#     if not socket.assigns.video_async.ok? do
#       {:noreply, socket}
#     else
#       diff_parameter = diff_form_to_parameter(params)

#       socket =
#         socket
#         |> assign(:diff_async, AsyncResult.loading(socket.assigns.diff_async))
#         |> start_async(:diff_was_calculated, fn ->
#           {:ok, diff} =
#             Kin.Video.calculate_diff(socket.assigns.video_async.result, diff_parameter)

#           diff
#         end)

#       {:noreply, socket}
#     end
#   end

#   def diff_was_calculated({:ok, diff} = _result, %Socket{} = socket) do
#     old_diff_async = socket.assigns.diff_async

#     socket =
#       socket
#       |> assign(:diff_async, AsyncResult.ok(old_diff_async, diff))

#     {:noreply, socket}
#   end

#   def diff_was_calculated({:exit, reason} = _result, %Socket{} = socket) do
#     old_diff_async = socket.assigns.diff_async

#     socket =
#       socket
#       |> assign(:diff_async, AsyncResult.failed(old_diff_async, {:error, reason}))
#       |> put_flash(:error, "Failed to calculate diff")

#     {:noreply, socket}
#   end

#   defp diff_parameter_to_form(%{nw: {nw_x, nw_y}, se: {se_x, se_y}} = _diff_parameter) do
#     %{
#       "area_nw_x" => nw_x,
#       "area_nw_y" => nw_y,
#       "area_se_x" => se_x,
#       "area_se_y" => se_y
#     }
#   end

#   defp diff_form_to_parameter(diff_form) do
#     %{
#       nw: {diff_form["area_nw_x"], diff_form["area_nw_y"]},
#       se: {diff_form["area_se_x"], diff_form["area_se_y"]}
#     }
#   end

#   # Extracting frames
#   def update_extract_form(_params, %Socket{} = socket) do
#     {:error, "not implemented"}
#   end

#   def request_extracting_frames(_params, %Socket{} = socket) do
#     {:error, "not implemented"}
#   end

#   def frames_extracted(_params, %Socket{} = socket) do
#     {:error, "not implemented"}
#   end
# end
