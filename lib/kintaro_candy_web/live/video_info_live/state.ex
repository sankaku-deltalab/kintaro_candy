defmodule KinWeb.VideoInfoLive.State.VideoFramesExtracted do
  defstruct [
    :video,
    target_frames: %{}
  ]

  @type t :: %__MODULE__{
          video: Kin.Video.t(),
          target_frames: %{non_neg_integer() => Mat.t()}
        }
end

defmodule KinWeb.VideoInfoLive.State.VideoDiffCalculated do
  alias KinWeb.VideoInfoLive.State.VideoFramesExtracted

  defstruct [
    :video,
    diff_from_prev_frame: %{},
    extract_parameter: %{diff_threshold: 10, stop_frames_length: 20}
  ]

  @type t :: %__MODULE__{
          video: Kin.Video.t(),
          diff_from_prev_frame: %{non_neg_integer() => float()},
          extract_parameter: extract_parameter()
        }

  @type extract_parameter :: Kin.Video.extract_parameter()

  @spec set_extract_parameter(t(), extract_parameter()) :: t()
  def set_extract_parameter(%__MODULE__{} = state, parameter) do
    %{state | extract_parameter: parameter}
  end

  @spec extract_frames(t()) :: {:ok, VideoFramesExtracted.t()} | {:error, any()}
  def extract_frames(%__MODULE__{} = state) do
    with keys <-
           Kin.Video.extract_keys_when_stopped(
             state.diff_from_prev_frame,
             state.extract_parameter
           ),
         {:ok, frames} <- Kin.Video.extract_frames_from_keys(state.video, keys) do
      {:ok,
       %VideoFramesExtracted{
         video: state.video,
         target_frames: frames
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end
end

defmodule KinWeb.VideoInfoLive.State.VideoLoaded do
  alias KinWeb.VideoInfoLive.State.VideoDiffCalculated

  defstruct [
    :video,
    chosen_video_frame: {-1, ""},
    diff_parameter: %{nw: {0, 0}, se: {1920, 1080}}
  ]

  @type t :: %__MODULE__{
          video: Kin.Video.t(),
          chosen_video_frame: {integer(), URI.t()},
          diff_parameter: diff_parameter()
        }

  @type diff_parameter :: Kin.Video.diff_parameter()

  @spec load_video(Path.t()) :: {:ok, t()} | {:error, any()}
  def load_video(filepath) do
    with {:ok, video} <- Kin.Video.load_video(filepath) do
      area = %{nw: {0, 0}, se: video.frame_size}

      {:ok,
       %__MODULE__{video: video, chosen_video_frame: {0, ""}, diff_parameter: area}
       |> update_frame_uri()}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec load_video!(Path.t()) :: t()
  def load_video!(filepath) do
    {:ok, video} = load_video(filepath)
    video
  end

  @spec set_diff_parameter(t(), diff_parameter()) :: t()
  def set_diff_parameter(%__MODULE__{} = state, area) do
    %{state | diff_parameter: area} |> update_frame_uri()
  end

  @spec calculate_diff(t()) :: {:ok, VideoDiffCalculated.t()} | {:error, any()}
  def calculate_diff(%__MODULE__{} = state) do
    case Kin.Video.calculate_diff(state.video, state.diff_parameter) do
      {:ok, diff} ->
        {:ok,
         %VideoDiffCalculated{
           video: state.video,
           diff_from_prev_frame: diff
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp update_frame_uri(%__MODULE__{} = state) do
    key = state.chosen_video_frame |> elem(0)

    case Kin.Video.get_example_frame_drawn_area(
           state.video,
           key,
           state.diff_parameter
         ) do
      {:ok, frame} ->
        frame_uri = frame |> Kin.Video.frame_to_base64()
        %{state | chosen_video_frame: {key, frame_uri}}

      {:error, _reason} ->
        state
    end
  end
end
