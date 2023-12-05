defmodule KinWeb.VideoInfoLiveTest do
  use KinWeb.ConnCase

  import Phoenix.LiveViewTest
  import Kin.VideoSlicingFixtures

  @create_attrs %{}
  @update_attrs %{}
  @invalid_attrs %{}

  defp create_video_info(_) do
    video_info = video_info_fixture()
    %{video_info: video_info}
  end

  describe "Index" do
    setup [:create_video_info]

    test "lists all video_infos", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/video_infos")

      assert html =~ "Listing Video infos"
    end

    test "saves new video_info", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/video_infos")

      assert index_live |> element("a", "New Video info") |> render_click() =~
               "New Video info"

      assert_patch(index_live, ~p"/video_infos/new")

      assert index_live
             |> form("#video_info-form", video_info: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#video_info-form", video_info: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/video_infos")

      html = render(index_live)
      assert html =~ "Video info created successfully"
    end

    test "updates video_info in listing", %{conn: conn, video_info: video_info} do
      {:ok, index_live, _html} = live(conn, ~p"/video_infos")

      assert index_live |> element("#video_infos-#{video_info.id} a", "Edit") |> render_click() =~
               "Edit Video info"

      assert_patch(index_live, ~p"/video_infos/#{video_info}/edit")

      assert index_live
             |> form("#video_info-form", video_info: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#video_info-form", video_info: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/video_infos")

      html = render(index_live)
      assert html =~ "Video info updated successfully"
    end

    test "deletes video_info in listing", %{conn: conn, video_info: video_info} do
      {:ok, index_live, _html} = live(conn, ~p"/video_infos")

      assert index_live |> element("#video_infos-#{video_info.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#video_infos-#{video_info.id}")
    end
  end

  describe "Show" do
    setup [:create_video_info]

    test "displays video_info", %{conn: conn, video_info: video_info} do
      {:ok, _show_live, html} = live(conn, ~p"/video_infos/#{video_info}")

      assert html =~ "Show Video info"
    end

    test "updates video_info within modal", %{conn: conn, video_info: video_info} do
      {:ok, show_live, _html} = live(conn, ~p"/video_infos/#{video_info}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Video info"

      assert_patch(show_live, ~p"/video_infos/#{video_info}/show/edit")

      assert show_live
             |> form("#video_info-form", video_info: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#video_info-form", video_info: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/video_infos/#{video_info}")

      html = render(show_live)
      assert html =~ "Video info updated successfully"
    end
  end
end
