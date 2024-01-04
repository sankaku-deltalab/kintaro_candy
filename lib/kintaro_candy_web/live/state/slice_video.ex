defmodule KinWeb.State.Slice.VideoSlice do
  alias Phoenix.LiveView
  alias Phoenix.LiveView.AsyncResult
  alias Phoenix.LiveView.Socket
  alias Evision.Mat
  alias Kin.Video

  @initial_state %{
    video_async: %AsyncResult{},
    frame_uri_for_diff_async: %AsyncResult{},
    diff_async: %AsyncResult{},
    extracted_frames_async: %AsyncResult{}
  }

  @type async(result) :: %AsyncResult{result: nil | result}

  @type t :: %{
          video_async: async(Video.t()),
          frame_uri_for_diff_async: async(String.t()),
          diff_async:
            async(%{params: Video.diff_parameter(), diff: %{non_neg_integer() => Mat.t()}}),
          extracted_frames_async:
            async(%{params: Video.extract_parameter(), frames: %{non_neg_integer() => Mat.t()}})
        }

  alias KinWeb.State.Slice.VideoSlice.{LoadVideoAsync, RedrawFrameForDiffAsync, CalcDiff}

  use Rephex.Slice,
    async_modules: [LoadVideoAsync, RedrawFrameForDiffAsync, CalcDiff],
    initial_state: @initial_state

  # Action

  # Selector

  def loading_video?(%Socket{} = socket) do
    socket
    |> Support.get_slice()
    |> Map.fetch!(:video_async)
    |> then(fn %AsyncResult{loading: loading} -> loading != nil end)
  end
end

defmodule KinWeb.State.Slice.VideoSlice.LoadVideoAsync do
  alias Phoenix.LiveView.Socket
  alias Phoenix.LiveView

  alias KinWeb.State.Slice.VideoSlice
  alias KinWeb.State.Slice.VideoSlice.Support

  @type payload :: %{video_path: String.t()}
  @type message :: any()
  use Rephex.AsyncAction, slice: KinWeb.State.Slice.VideoSlice

  def before_async(%Socket{} = socket, %{video_path: video_path} = _payload) do
    cond do
      VideoSlice.loading_video?(socket) ->
        {:abort, LiveView.put_flash(socket, :error, "Video is loading now")}

      not File.exists?(video_path) ->
        {:abort, LiveView.put_flash(socket, :error, "Video file not exist")}

      true ->
        socket =
          socket
          |> Support.update_async!(:video_async, loading: true)
          |> Support.update_async!(:frame_uri_for_diff_async, loading: true)
          |> LiveView.put_flash(:info, "Loading video ...")

        {:continue, socket}
    end
  end

  def start_async(_state, %{video_path: video_path} = _payload, _send_msg)
      when is_bitstring(video_path) do
    {:ok, video} = Kin.Video.load_video(video_path)

    diff_parameter = %{nw: {0, 0}, se: video.frame_size}
    key = video.example_frames |> Map.keys() |> Enum.min()
    {:ok, diff_frame} = Kin.Video.get_example_frame_drawn_area(video, key, diff_parameter)
    diff_frame_uri = Kin.Video.frame_to_base64(diff_frame)

    {video, diff_frame_uri}
  end

  def resolve(%Socket{} = socket, result) do
    case result do
      {:ok, {%Kin.Video{} = video, diff_frame_uri}} ->
        socket
        |> Support.update_async!(:video_async, ok: video)
        |> Support.update_async!(:frame_uri_for_diff_async, ok: diff_frame_uri)
        |> LiveView.put_flash(:info, "Video loading succeed")

      {:exit, reason} ->
        socket
        |> Support.update_async!(:video_async, failed: reason)
        |> Support.update_async!(:frame_uri_for_diff_async, failed: reason)
        |> LiveView.put_flash(:error, "Video loading failed")
    end
  end

  def receive_message(%Socket{} = socket, _content) do
    socket
  end

  def canceled(%Socket{} = socket, _reason) do
    socket
  end
end

defmodule KinWeb.State.Slice.VideoSlice.RedrawFrameForDiffAsync do
  alias Phoenix.LiveView.AsyncResult
  alias Phoenix.LiveView.Socket

  alias KinWeb.State.Slice.VideoSlice.Support

  @type diff_parameter :: Kin.Video.diff_parameter()

  @type payload :: %{diff_parameter: diff_parameter(), frame_key: non_neg_integer()}
  @type message :: any()

  use Rephex.AsyncAction, slice: KinWeb.State.Slice.VideoSlice

  def before_async(%Socket{} = socket, _payload) do
    {:continue, socket |> Support.update_async!(:frame_uri_for_diff_async, loading: true)}
  end

  def start_async(
        %{video_async: %AsyncResult{} = video_async} = _state,
        %{diff_parameter: params, frame_key: key} = _payload,
        _send_msg
      ) do
    if not video_async.ok?, do: raise("Video not loaded")

    {:ok, diff_frame} =
      Kin.Video.get_example_frame_drawn_area(video_async.result, key, params)

    Kin.Video.frame_to_base64(diff_frame)
  end

  def resolve(%Socket{} = socket, result) do
    case result do
      {:ok, diff_frame_uri} ->
        socket
        |> Support.update_async!(:frame_uri_for_diff_async, ok: diff_frame_uri)

      {:exit, reason} ->
        socket
        |> Support.update_async!(:frame_uri_for_diff_async, failed: reason)
    end
  end

  def receive_message(%Socket{} = socket, _content) do
    socket
  end

  def canceled(%Socket{} = socket, _reason) do
    socket
  end
end

defmodule KinWeb.State.Slice.VideoSlice.CalcDiff do
  alias Phoenix.LiveView.AsyncResult
  alias Phoenix.LiveView.Socket
  alias Phoenix.LiveView

  alias KinWeb.State.Slice.VideoSlice.Support

  @type diff_parameter :: Kin.Video.diff_parameter()

  @type payload :: %{diff_parameter: diff_parameter()}
  @type message :: any()

  use Rephex.AsyncAction, slice: KinWeb.State.Slice.VideoSlice

  def before_async(%Socket{} = socket, _payload) do
    {:continue,
     socket
     |> Support.update_async!(:diff_async, loading: true)
     |> LiveView.put_flash(:info, "Start calculating diff ...")}
  end

  def start_async(
        %{video_async: %AsyncResult{} = video_async} = _state,
        %{diff_parameter: params} = _payload,
        _send_msg
      ) do
    if not video_async.ok?, do: raise("Video not loaded")

    {:ok, diff} = Kin.Video.calculate_diff(video_async.result, params)
    %{params: params, diff: diff}
  end

  def resolve(%Socket{} = socket, result) do
    case result do
      {:ok, %{params: _, diff: _} = val} ->
        socket
        |> Support.update_async!(:diff_async, ok: val)
        |> LiveView.put_flash(:info, "Diff calculation succeed")

      {:exit, reason} ->
        socket
        |> Support.update_async!(:diff_async, failed: reason)
        |> LiveView.put_flash(:error, "Diff calculation failed")
    end
  end

  def receive_message(%Socket{} = socket, _content) do
    socket
  end

  def canceled(%Socket{} = socket, _reason) do
    socket
  end
end
