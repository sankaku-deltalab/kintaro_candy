defmodule KinWeb.VideoInfoLive.Index do
  use KinWeb, :live_view

  alias Phoenix.LiveView.AsyncResult
  alias Phoenix.LiveView.Socket

  @initial_state %{
    # video loading
    loading_form: to_form(%{"video_path" => ""}),
    video_async: %AsyncResult{},
    # diff calculation
    frame_uri_for_diff_params_async: %AsyncResult{},
    diff_parameter_form:
      to_form(%{
        "area_nw_x" => "0",
        "area_nw_y" => "0",
        "area_se_x" => "0",
        "area_se_y" => "0"
      }),
    diff_async: %AsyncResult{},
    # frame extraction
    extract_parameter_form: to_form(%{"diff_threshold" => "10", "stop_frames_length" => "20"}),
    extracted_frames_async: %AsyncResult{},
    # Output
    output_path_form: to_form(%{"output_directory_path" => ""})
  }

  @impl true
  def mount(_params, _session, %Socket{} = socket) do
    socket =
      socket
      |> assign(@initial_state)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, %Socket{} = socket) do
    {:noreply, socket}
  end

  # Video loading

  @impl true
  def handle_event("update_loading_form", params, %Socket{} = socket) do
    # TODO: validate path
    socket = socket |> assign(:loading_form, to_form(params))

    {:noreply, socket}
  end

  @impl true
  def handle_event("request_loading_video", %{"video_path" => video_path}, %Socket{} = socket) do
    socket =
      socket
      |> set_async_as_loading(:video_async)
      |> set_async_as_loading(:frame_uri_for_diff_params_async)
      |> start_async(:video_was_loaded, fn ->
        {:ok, video} = Kin.Video.load_video(video_path)
        diff_parameter = %{nw: {0, 0}, se: video.frame_size}
        {:ok, frame} = Kin.Video.get_example_frame_drawn_area(video, 0, diff_parameter)

        {video, frame}
      end)

    {:noreply, socket}
  end

  # Diff calculation

  @impl true
  def handle_event("update_diff_form", params, %Socket{} = socket) do
    socket = socket |> assign(:diff_parameter_form, to_form(params))

    video_async = socket.assigns.video_async
    frame_uri_for_diff_params_async = socket.assigns.frame_uri_for_diff_params_async

    socket =
      with %AsyncResult{ok?: true, result: %Kin.Video{} = video} <- video_async,
           %AsyncResult{loading: loading} when loading == nil <-
             frame_uri_for_diff_params_async do
        socket
        |> set_async_as_loading(:frame_uri_for_diff_params_async)
        |> start_async(:frame_for_diff_is_loaded, fn ->
          diff_parameter = params |> to_form() |> diff_form_to_parameter()
          {:ok, frame} = Kin.Video.get_example_frame_drawn_area(video, 0, diff_parameter)

          {diff_parameter, frame}
        end)
      else
        _ -> socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("request_calculating_diff", params, %Socket{} = socket) do
    cond do
      not socket.assigns.video_async.ok? ->
        socket = socket |> put_flash(:error, "Video is not loaded")
        {:noreply, socket}

      socket.assigns.diff_async.loading != nil ->
        socket = socket |> put_flash(:error, "Diff is calculating")
        {:noreply, socket}

      true ->
        diff_parameter = params |> to_form() |> diff_form_to_parameter()

        socket =
          socket
          |> set_async_as_loading(:diff_async)
          |> start_async(:diff_was_calculated, fn ->
            {:ok, diff} =
              Kin.Video.calculate_diff(socket.assigns.video_async.result, diff_parameter)

            {diff_parameter, diff}
          end)

        {:noreply, socket}
    end
  end

  # Frame extraction

  @impl true
  def handle_event("update_extract_form", params, %Socket{} = socket) do
    socket = socket |> assign(:extract_parameter_form, to_form(params))

    {:noreply, socket}
  end

  @impl true
  def handle_event("request_extracting_frames", params, %Socket{} = socket) do
    video_async = socket.assigns.video_async
    diff_async = socket.assigns.diff_async

    with %AsyncResult{ok?: true, result: %Kin.Video{} = video} <- video_async,
         %AsyncResult{ok?: true, result: diff} <- diff_async do
      extract_params = %{
        diff_threshold: String.to_integer(params["diff_threshold"]),
        stop_frames_length: String.to_integer(params["stop_frames_length"])
      }

      socket =
        socket
        |> set_async_as_loading(:extracted_frames_async)
        |> start_async(:frames_are_extracted, fn ->
          {:ok, frames} =
            diff
            |> Kin.Video.extract_keys_when_stopped(extract_params)
            |> then(&Kin.Video.extract_frames_from_keys(video, &1))

          frames
        end)

      {:noreply, socket}
    else
      _ -> {:noreply, socket}
    end
  end

  # Output

  @impl true
  def handle_event("update_output_form", params, %Socket{} = socket) do
    socket = socket |> assign(:output_path_form, to_form(params))

    {:noreply, socket}
  end

  @impl true
  def handle_event("request_output_frames", params, %Socket{} = socket) do
    video_async = socket.assigns.video_async
    extracted_frames_async = socket.assigns.extracted_frames_async

    with %AsyncResult{ok?: true, result: %Kin.Video{} = _video} <- video_async,
         %AsyncResult{ok?: true, result: target_frames} <- extracted_frames_async do
      output_directory_path = params["output_directory_path"]

      socket =
        socket
        |> start_async(:frames_are_outputted, fn ->
          Kin.Video.write_frames(target_frames, output_directory_path)
        end)

      {:noreply, socket}
    else
      _ -> {:noreply, socket}
    end
  end

  # Video loading

  def handle_async(
        :video_was_loaded,
        {:ok, {%Kin.Video{} = video, %Evision.Mat{} = frame}},
        %Socket{} = socket
      ) do
    frame_uri = Kin.Video.frame_to_base64(frame)

    socket =
      socket
      |> set_async_as_ok(:video_async, video)
      |> set_async_as_ok(:frame_uri_for_diff_params_async, frame_uri)
      |> assign(:diff_parameter_form, diff_parameter_to_form(%{nw: {0, 0}, se: video.frame_size}))

    {:noreply, socket}
  end

  def handle_async(:video_was_loaded, {:exit, reason}, %Socket{} = socket) do
    socket =
      socket
      |> set_async_as_failed(:video_async, {:error, reason})
      |> put_flash(:error, "Failed to load video")

    {:noreply, socket}
  end

  # Diff calculation

  def handle_async(:diff_was_calculated, {:ok, {_diff_parameter, diff}}, socket) do
    socket =
      socket
      |> set_async_as_ok(:diff_async, diff)
      |> put_flash(:info, "Diff was calculated")

    {:noreply, socket}
  end

  def handle_async(:diff_was_calculated, {:exit, reason}, socket) do
    socket =
      socket
      |> set_async_as_failed(:diff_async, {:error, reason})
      |> put_flash(:error, "Failed to calculate diff")

    {:noreply, socket}
  end

  def handle_async(
        :frame_for_diff_is_loaded,
        {:ok, {diff_params, %Evision.Mat{} = frame}},
        %Socket{} = socket
      ) do
    current_diff_parameter =
      socket.assigns.diff_parameter_form
      |> diff_form_to_parameter()

    frame_uri = Kin.Video.frame_to_base64(frame)

    socket =
      socket
      |> set_async_as_ok(:frame_uri_for_diff_params_async, frame_uri)

    if diff_params == current_diff_parameter do
      socket
    else
      # reload frame for diff if diff parameter is changed
      socket
      |> set_async_as_loading(:frame_uri_for_diff_params_async)
      |> start_async(:frame_uri_for_diff_params_async, fn ->
        {:ok, diff} =
          Kin.Video.calculate_diff(socket.assigns.video_async.result, current_diff_parameter)

        {current_diff_parameter, diff}
      end)
    end

    {:noreply, socket}
  end

  def handle_async(:frame_for_diff_is_loaded, {:exit, reason}, %Socket{} = socket) do
    socket =
      socket
      |> set_async_as_failed(:video_async, {:error, reason})
      |> put_flash(:error, "Failed to load video")

    {:noreply, socket}
  end

  # Frame extraction

  def handle_async(:frames_are_extracted, {:ok, frames}, socket) do
    old_frames = socket.assigns.extracted_frames_async

    socket =
      socket
      |> assign(:extracted_frames_async, AsyncResult.ok(old_frames, frames))

    {:noreply, socket}
  end

  def handle_async(:frames_are_extracted, {:exit, reason}, socket) do
    old_frames = socket.assigns.extracted_frames_async

    socket =
      socket
      |> assign(:extracted_frames_async, AsyncResult.failed(old_frames, {:error, reason}))
      |> put_flash(:error, "Failed to Extract frames")

    {:noreply, socket}
  end

  # Output

  def handle_async(:frames_are_outputted, {:ok, _frames}, socket) do
    socket =
      socket
      |> put_flash(:info, "Succeed to save!")

    {:noreply, socket}
  end

  def handle_async(:frames_are_outputted, {:exit, _reason}, socket) do
    socket =
      socket
      |> put_flash(:info, "Failed to save!")

    {:noreply, socket}
  end

  defp diff_parameter_to_form(%{nw: {nw_x, nw_y}, se: {se_x, se_y}} = _diff_parameter) do
    %{
      "area_nw_x" => nw_x,
      "area_nw_y" => nw_y,
      "area_se_x" => se_x,
      "area_se_y" => se_y
    }
    |> to_form()
  end

  defp diff_form_to_parameter(%Phoenix.HTML.Form{} = diff_form) do
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

  defp set_async_as_loading(%Socket{} = socket, key) do
    socket
    |> assign(key, AsyncResult.loading(Map.fetch!(socket.assigns, key)))
  end

  defp set_async_as_ok(%Socket{} = socket, key, result) do
    socket
    |> assign(key, AsyncResult.ok(Map.fetch!(socket.assigns, key), result))
  end

  defp set_async_as_failed(%Socket{} = socket, key, reason) do
    socket
    |> assign(key, AsyncResult.failed(Map.fetch!(socket.assigns, key), reason))
  end
end
