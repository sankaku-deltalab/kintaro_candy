defmodule KinWeb.State do
  alias Phoenix.LiveView.{AsyncResult, Socket}
  alias Evision.Mat
  alias Kin.Video

  @initial_state %{
    video_async: %AsyncResult{},
    diff_async: %AsyncResult{},
    extraction_keys_async: %AsyncResult{},
    extracted_frames_async: %AsyncResult{},
    store_frames_async: %AsyncResult{}
  }

  @type async(result) :: %AsyncResult{result: nil | result}

  @type t :: %{
          video_async: async(Video.t()),
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

defmodule KinWeb.State.ScrollInto do
  @type payload :: %{dom_id: String.t()}

  use Rephex.AsyncAction, payload_type: payload()

  def start_async(_state, %{dom_id: dom_id} = _payload, _) do
    # Wait dom mount
    :timer.sleep(100)
    dom_id
  end

  def resolve(socket, result) do
    case result do
      {:ok, dom_id} ->
        socket
        |> Phoenix.LiveView.push_event("scroll_into_view", %{id: dom_id})

      _ ->
        socket
    end
  end
end

defmodule KinWeb.State.LoadVideoAsync do
  @type payload :: %{video_path: String.t()}
  @type message :: any()
  @type cancel_reason :: any()

  use Rephex.AsyncAction.Simple, async_keys: [:video_async]

  def start_async(_state, %{video_path: video_path} = _payload, progress)
      when is_bitstring(video_path) do
    progress.(true)
    {:ok, video} = Kin.Video.load_video(video_path)
    video
  end

  def after_async(socket, result) do
    case result do
      {:ok, _} ->
        socket |> KinWeb.State.ScrollInto.start(%{dom_id: "calculating_diff"})

      _ ->
        socket
    end
  end
end

defmodule KinWeb.State.CalcDiffAsync do
  alias Phoenix.LiveView.AsyncResult

  @type diff_parameter :: Kin.Video.diff_parameter()

  @type payload :: %{diff_parameter: diff_parameter()}
  @type message :: {current :: non_neg_integer(), total :: non_neg_integer()}
  @type result :: %{params: diff_parameter(), diff: %{non_neg_integer() => non_neg_integer()}}

  use Rephex.AsyncAction.Simple, async_keys: [:diff_async]

  def option(), do: %{throttle: 50}

  def initial_loading_state(_state, _payload), do: {0, 1}

  def start_async(
        %{video_async: %AsyncResult{} = video_async} = _state,
        %{diff_parameter: params} = _payload,
        progress
      ) do
    if not video_async.ok?, do: exit({:shutdown, :video_not_loaded})
    progress.({0, 1})

    {:ok, diff} = Kin.Video.calculate_diff(video_async.result, params, progress)
    %{params: params, diff: diff}
  end

  def after_async(socket, result) do
    case result do
      {:ok, _} ->
        socket |> KinWeb.State.ScrollInto.start(%{dom_id: "frames_extraction"})

      _ ->
        socket
    end
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

  def after_async(socket, result) do
    case result do
      {:ok, _} ->
        socket |> KinWeb.State.ScrollInto.start(%{dom_id: "store_frames"})

      _ ->
        socket
    end
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
