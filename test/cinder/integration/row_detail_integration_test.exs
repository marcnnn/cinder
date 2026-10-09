defmodule Cinder.Integration.RowDetailTest do
  @moduledoc """
  Full-lifecycle coverage for the `row_detail` slot: it reaches the table renderer
  through both `Cinder.collection` and the deprecated `Cinder.Table.table`, and
  list and grid layouts render it inside each item.
  """
  use Cinder.ConnCase, async: false

  alias Cinder.TestLive.Fixture

  defp collection_with_detail(assigns) do
    ~H"""
    <Cinder.collection resource={Cinder.Integration.Album} url_state={@url_state}>
      <:col :let={album} field="title" filter sort>{album.title}</:col>
      <:row_detail :let={album}>Genre: {album.genre}</:row_detail>
    </Cinder.collection>
    """
  end

  defp table_with_detail(assigns) do
    ~H"""
    <Cinder.Table.table resource={Cinder.Integration.Album} url_state={@url_state}>
      <:col :let={album} field="title" filter sort>{album.title}</:col>
      <:row_detail :let={album}>Genre: {album.genre}</:row_detail>
    </Cinder.Table.table>
    """
  end

  defp list_with_detail(assigns) do
    ~H"""
    <Cinder.collection resource={Cinder.Integration.Album} layout={:list}>
      <:col field="title" sort />
      <:item :let={album}>{album.title}</:item>
      <:row_detail :let={album}>Genre: {album.genre}</:row_detail>
    </Cinder.collection>
    """
  end

  defp grid_with_detail(assigns) do
    ~H"""
    <Cinder.collection resource={Cinder.Integration.Album} layout={:grid}>
      <:col field="title" sort />
      <:item :let={album}>{album.title}</:item>
      <:row_detail :let={album}>Genre: {album.genre}</:row_detail>
    </Cinder.collection>
    """
  end

  setup do
    artist = generate(artist(name: "Detail Artist"))
    jazz = generate(album(title: "Jazz Album", genre: :jazz, artist_id: artist.id))
    rock = generate(album(title: "Rock Album", genre: :rock, artist_id: artist.id))

    on_exit(fn ->
      Ash.bulk_destroy!(Cinder.Integration.Album, :destroy, %{})
      Ash.bulk_destroy!(Cinder.Integration.Artist, :destroy, %{})
    end)

    %{jazz: jazz, rock: rock}
  end

  test "Cinder.collection renders a detail row beneath each record", %{
    conn: conn,
    jazz: jazz,
    rock: rock
  } do
    path = Fixture.register(&collection_with_detail/1)

    conn
    |> visit(path)
    |> assert_has("tr[data-row-detail-for='#{jazz.id}'] td", text: "Genre: jazz")
    |> assert_has("tr[data-row-detail-for='#{rock.id}'] td", text: "Genre: rock")
  end

  test "detail rows follow the records when filtering", %{conn: conn, jazz: jazz, rock: rock} do
    path = Fixture.register(&collection_with_detail/1)

    conn
    |> visit(path <> "?title=Jazz")
    |> assert_has("tr[data-row-detail-for='#{jazz.id}']")
    |> refute_has("tr[data-row-detail-for='#{rock.id}']")
  end

  test "Cinder.Table.table passes the slot through", %{conn: conn, jazz: jazz} do
    path = Fixture.register(&table_with_detail/1)

    conn
    |> visit(path)
    |> assert_has("tr[data-row-detail-for='#{jazz.id}'] td", text: "Genre: jazz")
  end

  test "list layout renders the detail inside each item", %{conn: conn, jazz: jazz} do
    path = Fixture.register(&list_with_detail/1)

    conn
    |> visit(path)
    |> assert_has("*", text: "Jazz Album")
    |> assert_has("div[data-row-detail-for='#{jazz.id}']", text: "Genre: jazz")
    |> refute_has("tr[data-row-detail-for='#{jazz.id}']")
  end

  test "grid layout renders the detail inside each item", %{conn: conn, rock: rock} do
    path = Fixture.register(&grid_with_detail/1)

    conn
    |> visit(path)
    |> assert_has("div[data-row-detail-for='#{rock.id}']", text: "Genre: rock")
  end
end
