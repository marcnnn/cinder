defmodule Cinder.Integration.EmbersTest do
  @moduledoc """
  Full-lifecycle coverage for the `embers` slot: Cinder loads the relationship
  itself, renders one row per related record beneath its parent, honours the
  slot's `query` and `empty`, and list layouts neither load nor render it.
  """
  use Cinder.ConnCase, async: false

  require Ash.Query

  alias Cinder.Integration.{Album, Artist}
  alias Cinder.TestLive.Fixture

  defp artists_with_albums(assigns) do
    ~H"""
    <Cinder.collection resource={Artist} url_state={@url_state}>
      <:col :let={artist} field="name" filter sort>{artist.name}</:col>
      <:filter field="albums.title" type={:text} label="Album" />
      <:embers :let={album} relationship={:albums} empty="No albums">
        <td class="album-title">{album.title}</td>
        <td class="album-genre">{album.genre}</td>
      </:embers>
    </Cinder.collection>
    """
  end

  defp artists_with_rock_albums(assigns) do
    assigns =
      assign(
        assigns,
        :albums,
        Album |> Ash.Query.filter(genre == :rock) |> Ash.Query.sort(title: :desc)
      )

    ~H"""
    <Cinder.collection resource={Artist} url_state={@url_state}>
      <:col :let={artist} field="name" sort>{artist.name}</:col>
      <:embers :let={album} relationship={:albums} query={@albums}>
        <td class="album-title">{album.title}</td>
      </:embers>
    </Cinder.collection>
    """
  end

  defp albums_with_siblings(assigns) do
    ~H"""
    <Cinder.collection resource={Album} url_state={@url_state}>
      <:col :let={album} field="title" sort>{album.title}</:col>
      <:embers :let={sibling} relationship={[:artist, :albums]}>
        <td class="sibling-title">{sibling.title}</td>
      </:embers>
    </Cinder.collection>
    """
  end

  defp artists_as_list(assigns) do
    ~H"""
    <Cinder.collection resource={Artist} layout={:list}>
      <:col field="name" sort />
      <:item :let={artist}>{artist.name}</:item>
      <:embers :let={album} relationship={:albums}>
        <td>{album.title}</td>
      </:embers>
    </Cinder.collection>
    """
  end

  setup do
    tide = generate(artist(name: "Tide"))
    quiet = generate(artist(name: "Quiet"))
    generate(album(title: "Breakers", genre: :rock, artist_id: tide.id))
    generate(album(title: "Undertow", genre: :rock, artist_id: tide.id))
    generate(album(title: "Shoreline", genre: :jazz, artist_id: tide.id))

    on_exit(fn ->
      Ash.bulk_destroy!(Album, :destroy, %{})
      Ash.bulk_destroy!(Artist, :destroy, %{})
    end)

    %{tide: tide, quiet: quiet}
  end

  test "loads the relationship and renders a row per related record", %{conn: conn, tide: tide} do
    conn
    |> visit(Fixture.register(&artists_with_albums/1))
    |> assert_has("tr[data-ember-for='#{tide.id}'] td.album-title", text: "Breakers")
    |> assert_has("tr[data-ember-for='#{tide.id}'] td.album-title", text: "Undertow")
    |> assert_has("tr[data-ember-for='#{tide.id}'] td.album-genre", text: "jazz")
  end

  test "a record without related records gets the empty row", %{conn: conn, quiet: quiet} do
    conn
    |> visit(Fixture.register(&artists_with_albums/1))
    |> assert_has("tr[data-ember-for='#{quiet.id}'] td[colspan]", text: "No albums")
  end

  test "the slot's query filters and sorts the related records", %{conn: conn, tide: tide} do
    conn
    |> visit(Fixture.register(&artists_with_rock_albums/1))
    # Sorted descending: Undertow's row comes first, Breakers' right after it.
    |> assert_has(
      "tr[data-ember-for='#{tide.id}'] + tr[data-ember-for='#{tide.id}'] td.album-title",
      text: "Breakers"
    )
    |> refute_has(
      "tr[data-ember-for='#{tide.id}'] + tr[data-ember-for='#{tide.id}'] td.album-title",
      text: "Undertow"
    )
    |> refute_has("td.album-title", text: "Shoreline")
  end

  test "without empty, a record without related records gets no ember rows", %{
    conn: conn,
    quiet: quiet
  } do
    conn
    |> visit(Fixture.register(&artists_with_rock_albums/1))
    |> refute_has("tr[data-ember-for='#{quiet.id}']")
  end

  test "a relationship path reaches through other relationships", %{conn: conn} do
    conn
    |> visit(Fixture.register(&albums_with_siblings/1))
    |> assert_has("td.sibling-title", text: "Shoreline")
  end

  test "a related-field filter narrows the parent rows", %{conn: conn, tide: tide, quiet: quiet} do
    conn
    |> visit(Fixture.register(&artists_with_albums/1) <> "?albums.title=Under")
    |> assert_has("tr[data-ember-for='#{tide.id}']")
    |> refute_has("tr[data-ember-for='#{quiet.id}']")
  end

  test "list layout ignores the slot", %{conn: conn} do
    conn
    |> visit(Fixture.register(&artists_as_list/1))
    |> assert_has("*", text: "Tide")
    |> refute_has("*", text: "Breakers")
  end
end
