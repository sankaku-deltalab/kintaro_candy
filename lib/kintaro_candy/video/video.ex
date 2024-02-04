defmodule Kin.Video do
  alias Evision.{VideoCapture, Mat}

  @enforce_keys [:filepath, :frame_count, :frame_size]
  defstruct filepath: "", frame_count: 0, frame_size: {0, 0}, example_frames: %{}

  @type t :: %__MODULE__{
          filepath: Path.t(),
          frame_count: non_neg_integer(),
          frame_size: {non_neg_integer(), non_neg_integer()},
          example_frames: %{non_neg_integer() => %Mat{}}
        }

  @spec load_video(Path.t()) :: {:ok, %__MODULE__{}} | {:error, any()}
  def load_video(filepath) do
    with %VideoCapture{} = cap <- VideoCapture.videoCapture(filepath),
         frame_size <- {cap.frame_width, cap.frame_height} do
      fetch_num = 100
      frame_interval = div(floor(cap.frame_count), fetch_num)

      example_frames =
        0..(fetch_num - 1)
        |> Enum.map(&(frame_interval * &1))
        |> Enum.uniq()
        |> Enum.map(fn k -> {k, load_frame_from_capture!(cap, k)} end)
        |> Enum.filter(fn {_k, maybe_map} -> is_struct(maybe_map, Mat) end)
        |> Enum.into(%{})

      {:ok,
       %__MODULE__{
         filepath: filepath,
         frame_count: cap.frame_count |> round(),
         frame_size: frame_size,
         example_frames: example_frames
       }}
    else
      {:error, message} -> {:error, message}
      false -> {:error, "Failed to load video"}
    end
  end

  @type diff :: %{non_neg_integer() => float()}

  @type diff_parameter :: %{
          nw: {non_neg_integer(), non_neg_integer()},
          se: {non_neg_integer(), non_neg_integer()}
        }

  @spec get_example_frame_drawn_area(t(), non_neg_integer(), diff_parameter()) ::
          {:error, binary()} | {:ok, Evision.Mat.t()}
  def get_example_frame_drawn_area(
        %__MODULE__{example_frames: example_frames} = _video,
        key,
        diff_param
      ) do
    with {:ok, %Mat{} = frame} <- Map.fetch(example_frames, key),
         %Mat{} = frame <- draw_area(frame, diff_param) do
      {:ok, frame}
    else
      :error -> {:error, "Failed to get example frame"}
      {:error, message} -> {:error, message}
    end
  end

  defp draw_area(frame, diff_param) do
    Evision.rectangle(frame, diff_param.nw, diff_param.se, {0, 0, 255})
  end

  def frame_to_base64(frame) do
    frame
    |> then(fn frame -> Evision.imencode(".png", frame) end)
    |> Base.encode64()
    |> then(&"data:image/png;base64,#{&1}")
  end

  @spec calculate_diff(
          %__MODULE__{},
          diff_parameter(),
          ({current :: non_neg_integer(), total :: non_neg_integer()} -> any())
        ) :: {:ok, diff()} | {:error, any()}
  def calculate_diff(
        %__MODULE__{filepath: filepath, frame_count: frame_count} = video,
        diff_parameter,
        progress_callback
      ) do
    progress_callback.({0, frame_count})

    result =
      with %VideoCapture{} = cap <- VideoCapture.videoCapture(filepath) do
        diff_list_init = []

        {:ok, diff_list} =
          with %Mat{} = frame <- VideoCapture.read(cap) do
            calculate_diff_recursive(
              diff_list_init,
              video,
              diff_parameter,
              cap,
              1,
              frame,
              progress_callback
            )
          else
            false -> diff_list_init
          end

        VideoCapture.release(cap)

        {:ok, diff_list |> Map.new()}
      else
        {:error, message} -> {:error, message}
      end

    result
  end

  defp calculate_diff_recursive(
         diff,
         %__MODULE__{frame_count: frame_count} = video,
         diff_parameter,
         %VideoCapture{} = cap,
         current_frame_count,
         %Mat{} = prev_frame,
         progress_callback
       ) do
    case VideoCapture.read(cap) do
      %Mat{} = frame ->
        progress_callback.({current_frame_count, frame_count})
        current_diff = calc_frame_diff(diff_parameter, prev_frame, frame)
        diff = [{current_frame_count, current_diff} | diff]

        calculate_diff_recursive(
          diff,
          video,
          diff_parameter,
          cap,
          current_frame_count + 1,
          frame,
          progress_callback
        )

      false ->
        {:ok, diff}

      {:error, message} ->
        {:error, message}
    end
  end

  defp calc_frame_diff(diff_parameter, %Mat{} = prev_frame, %Mat{} = current_frame) do
    {nw_x, nw_y} = diff_parameter.nw
    {se_x, se_y} = diff_parameter.se

    prev_frame = prev_frame[[nw_y..(se_y - 1), nw_x..(se_x - 1)]]
    current_frame = current_frame[[nw_y..(se_y - 1), nw_x..(se_x - 1)]]

    {r, g, b, _a} =
      Evision.absdiff(prev_frame, current_frame)
      |> Evision.mean()

    (r + g + b) / 3
  end

  @type extract_parameter :: %{
          diff_threshold: float() | integer(),
          stop_frames_length: pos_integer()
        }

  @spec extract_keys_when_stopped(diff(), extract_parameter()) :: list()
  def extract_keys_when_stopped(%{} = diff, %{
        diff_threshold: diff_threshold,
        stop_frames_length: stop_frames_length
      }) do
    stopped_keys =
      diff
      |> Enum.sort_by(fn {k, _v} -> k end)
      |> Enum.map(fn {_k, v} -> v end)
      |> Nx.tensor()
      |> Nx.window_max({stop_frames_length})
      |> Nx.to_list()
      |> Stream.with_index()
      |> Stream.filter(fn {v, _k} -> v < diff_threshold end)
      |> Stream.map(fn {_v, k} when is_integer(k) -> k end)
      |> Enum.to_list()

    stopped_keys_set =
      stopped_keys
      |> MapSet.new()

    stopped_keys
    |> Enum.filter(fn k -> (k + 1) not in stopped_keys_set end)
  end

  @spec extract_frames_from_keys(
          %__MODULE__{},
          [non_neg_integer()]
        ) :: {:error, any()} | {:ok, [%Mat{}]}
  def extract_frames_from_keys(%__MODULE__{} = video, keys) do
    with %VideoCapture{} = cap <- VideoCapture.videoCapture(video.filepath) do
      try do
        keys
        |> Enum.sort()
        |> Enum.map(&load_frame_from_capture!(cap, &1))
        |> then(fn frames -> {:ok, frames} end)
      catch
        {:error, message} -> {:error, message}
      after
        VideoCapture.release(cap)
      end
    else
      {:error, message} -> {:error, message}
    end
  end

  defp load_frame_from_capture(%VideoCapture{} = cap, key) when is_integer(key) do
    maybe_frame =
      cap
      |> tap(&VideoCapture.set(&1, Evision.Constant.cv_CAP_PROP_POS_FRAMES(), key))
      |> VideoCapture.read()

    case maybe_frame do
      %Mat{} = frame -> {:ok, frame}
      _ -> raise {:error, maybe_frame}
    end
  end

  defp load_frame_from_capture!(%VideoCapture{} = cap, key) when is_integer(key) do
    {:ok, frame} = load_frame_from_capture(cap, key)
    frame
  end

  @spec write_frames([%Mat{}], Path.t()) :: boolean()
  def write_frames(frames, dest_dir) do
    File.mkdir_p!(dest_dir)

    frames
    |> Enum.with_index()
    |> Enum.map(fn
      {%Mat{} = frame, i} ->
        dest = Path.join(dest_dir, "#{i}.png")
        Evision.imwrite(dest, frame)
    end)
    |> Enum.all?(&(&1 == true))
  end
end
