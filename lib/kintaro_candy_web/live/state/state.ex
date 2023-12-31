defmodule KinWeb.State do
  alias KinWeb.State.Slice.VideoSlice
  use Rephex.State, slices: [VideoSlice]
end
