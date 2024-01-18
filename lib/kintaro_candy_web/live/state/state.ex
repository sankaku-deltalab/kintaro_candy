defmodule KinWeb.State do
  alias Phoenix.LiveView.{AsyncResult, Socket}
  alias Evision.Mat
  alias Kin.Video

  @initial_state %{
    video_async: %AsyncResult{},
    frame_uri_for_diff_async: %AsyncResult{},
    diff_async: %AsyncResult{},
    extraction_keys_async: %AsyncResult{},
    extracted_frames_async: %AsyncResult{},
    store_frames_async: %AsyncResult{}
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

  use Rephex.State, initial_state: @initial_state

  # Action

  # Selector

  def loading_video?(%Socket{} = socket) do
    socket
    |> Rephex.State.Assigns.get_state()
    |> Map.fetch!(:video_async)
    |> then(fn %AsyncResult{loading: loading} -> loading != nil end)
  end
end

defmodule KinWeb.State.LoadVideoAsync do
  alias Phoenix.LiveView.{Socket, AsyncResult}
  import Rephex.State.Assigns

  @type payload :: %{video_path: String.t()}
  @type message :: any()
  @type cancel_reason :: any()

  use Rephex.AsyncAction

  def before_async(%Socket{} = socket, %{video_path: _} = _payload) do
    {:continue,
     socket
     |> update_state_in([:video_async], &AsyncResult.loading(&1))
     |> update_state_in([:frame_uri_for_diff_async], &AsyncResult.loading(&1))}
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
        |> update_state_in([:video_async], &AsyncResult.ok(&1, video))
        |> update_state_in([:frame_uri_for_diff_async], &AsyncResult.ok(&1, diff_frame_uri))

      {:exit, reason} ->
        socket
        |> update_state_in([:video_async], &AsyncResult.failed(&1, reason))
        |> update_state_in([:frame_uri_for_diff_async], &AsyncResult.failed(&1, reason))
    end
  end

  def receive_message(%Socket{} = socket, _content) do
    socket
  end

  def before_cancel(%Socket{} = socket, _reason) do
    {:continue, socket}
  end
end

defmodule KinWeb.State.RedrawFrameForDiffAsync do
  alias Phoenix.LiveView.AsyncResult

  @type diff_parameter :: Kin.Video.diff_parameter()

  @type payload :: %{diff_parameter: diff_parameter(), frame_key: non_neg_integer()}
  @type message :: any()

  use Rephex.AsyncAction.Simple, async_keys: [:frame_uri_for_diff_async]

  def start_async(
        %{video_async: %AsyncResult{} = video_async} = _state,
        %{diff_parameter: params, frame_key: key} = _payload,
        progress
      ) do
    if not video_async.ok?, do: exit({:shutdown, :video_not_loaded})
    progress.(true)

    {:ok, diff_frame} =
      Kin.Video.get_example_frame_drawn_area(video_async.result, key, params)

    Kin.Video.frame_to_base64(diff_frame)
  end
end

defmodule KinWeb.State.CalcDiffAsync do
  alias Phoenix.LiveView.AsyncResult

  @type diff_parameter :: Kin.Video.diff_parameter()

  @type payload :: %{diff_parameter: diff_parameter()}
  @type message :: any()
  @type result :: %{params: diff_parameter(), diff: %{non_neg_integer() => non_neg_integer()}}

  use Rephex.AsyncAction.Simple, async_keys: [:diff_async]

  def start_async(
        %{video_async: %AsyncResult{} = video_async} = _state,
        %{diff_parameter: params} = _payload,
        progress
      ) do
    if not video_async.ok?, do: exit({:shutdown, :video_not_loaded})
    progress.(true)

    {:ok, diff} = Kin.Video.calculate_diff(video_async.result, params)
    %{params: params, diff: diff}
  end
end

defmodule KinWeb.State.ExtractFramesAsync do
  @type extraction_parameter :: Kin.Video.extract_parameter()

  @type payload :: %{params: extraction_parameter()}
  @type message :: {current :: non_neg_integer(), total :: non_neg_integer()}
  @type result :: %{params: extraction_parameter(), frames: [Mat.t()]}

  use Rephex.AsyncAction.Simple, async_keys: [:extracted_frames_async]

  def start_async(
        %{video_async: video_async, diff_async: diff_async} = _state,
        %{params: params} = _payload,
        progress
      ) do
    if not video_async.ok?, do: exit({:shutdown, :video_not_loaded})
    if not diff_async.ok?, do: exit({:shutdown, :diff_not_calculated})
    progress.(true)

    keys = Kin.Video.extract_keys_when_stopped(diff_async.result.diff, params)
    # TODO: use callback for progress
    {:ok, frames} = Kin.Video.extract_frames_from_keys(video_async.result, keys)
    %{frames: frames, params: params}
  end
end

defmodule KinWeb.State.StoreFramesAsync do
  @type payload :: %{dest_directory: String.t()}
  @type message :: {current :: non_neg_integer(), total :: non_neg_integer()}
  @type result :: true

  use Rephex.AsyncAction.Simple, async_keys: [:store_frames_async]

  def start_async(
        %{
          video_async: video_async,
          diff_async: diff_async,
          extracted_frames_async: extracted_frames_async
        } = _state,
        %{dest_directory: dest_directory} = _payload,
        progress
      ) do
    if not video_async.ok?, do: exit({:shutdown, :video_not_loaded})
    if not diff_async.ok?, do: exit({:shutdown, :diff_not_calculated})
    if not extracted_frames_async.ok?, do: exit({:shutdown, :frames_not_extracted})
    progress.({0, 1})

    target_frames = extracted_frames_async.result.frames

    # TODO: use callback for progress
    true = Kin.Video.write_frames(target_frames, dest_directory)
  end
end
