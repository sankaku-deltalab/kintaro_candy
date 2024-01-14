defmodule KinWeb.VideoInfoLive.Index do
  use KinWeb, :live_view
  use Rephex.LiveView, state: KinWeb.State

  alias Phoenix.LiveView.Socket

  alias KinWeb.VideoInfoLive.{
    VideoLoadComponent,
    DiffCalcComponent,
    FramesExtractionComponent,
    StoreFramesComponent
  }

  @impl true
  def mount(_params, _session, %Socket{} = socket) do
    {:ok, socket |> KinWeb.State.init()}
  end

  @impl true
  def handle_params(_params, _url, %Socket{} = socket) do
    {:noreply, socket}
  end
end
