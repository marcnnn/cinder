defmodule Cinder.EmbersTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Cinder.Embers

  describe "children/2" do
    test "returns the loaded relationship" do
      item = %{members: [%{name: "a"}, %{name: "b"}]}

      assert Embers.children(item, %{relationship: :members}) ==
               {[%{name: "a"}, %{name: "b"}], false}
    end

    test "walks a path and flattens to-many hops" do
      item = %{teams: [%{members: [%{name: "a"}]}, %{members: [%{name: "b"}]}]}

      assert Embers.children(item, %{relationship: [:teams, :members]}) ==
               {[%{name: "a"}, %{name: "b"}], false}
    end

    test "wraps a to-one relationship" do
      assert Embers.children(%{lead: %{name: "a"}}, %{relationship: :lead}) ==
               {[%{name: "a"}], false}
    end

    test "treats nil, unloaded and forbidden values as no children" do
      assert Embers.children(%{members: nil}, %{relationship: :members}) == {[], false}

      assert Embers.children(%{members: %Ash.NotLoaded{}}, %{relationship: :members}) ==
               {[], false}

      assert Embers.children(%{org: nil}, %{relationship: [:org, :members]}) == {[], false}

      assert Embers.children(%{members: %Ash.ForbiddenField{}}, %{relationship: :members}) ==
               {[], false}
    end

    test "cuts the children off at limit and says whether there were more" do
      item = %{members: [%{name: "a"}, %{name: "b"}, %{name: "c"}]}

      assert Embers.children(item, %{relationship: :members, limit: 2}) ==
               {[%{name: "a"}, %{name: "b"}], true}

      assert Embers.children(item, %{relationship: :members, limit: 3}) ==
               {[%{name: "a"}, %{name: "b"}, %{name: "c"}], false}
    end

    test "applies limit after flattening a path" do
      item = %{teams: [%{members: [%{name: "a"}]}, %{members: [%{name: "b"}]}]}

      assert Embers.children(item, %{relationship: [:teams, :members], limit: 1}) ==
               {[%{name: "a"}], true}
    end

    test "rejects a limit that is not a positive integer" do
      assert_raise ArgumentError, ~r/limit must be a positive integer/, fn ->
        Embers.children(%{members: []}, %{relationship: :members, limit: 0})
      end
    end

    test "rejects a relationship that is not an atom or a list of atoms" do
      assert_raise ArgumentError, ~r/<:embers> needs relationship/, fn ->
        Embers.children(%{}, %{relationship: "members"})
      end
    end
  end

  describe "load/2" do
    test "leaves the query alone without embers" do
      assert Embers.load(Cinder.Integration.Artist, []) == Cinder.Integration.Artist
    end

    test "loads the relationship, through a path and with a query" do
      albums = Ash.Query.sort(Cinder.Integration.Album, title: :desc)

      query =
        Embers.load(Cinder.Integration.Album, [
          %{relationship: [:artist, :albums], query: albums}
        ])

      assert %Ash.Query{load: [artist: %Ash.Query{load: [albums: %Ash.Query{sort: sort}]}]} =
               query

      assert sort == [title: :desc]
    end

    test "loads one more than limit, overriding the query's limit" do
      albums = Cinder.Integration.Album |> Ash.Query.sort(title: :desc) |> Ash.Query.limit(10)

      assert %Ash.Query{load: [albums: %Ash.Query{limit: 4, sort: [title: :desc]}]} =
               Embers.load(Cinder.Integration.Artist, [
                 %{relationship: :albums, query: albums, limit: 3}
               ])
    end

    test "builds a query on the related resource for limit without a query" do
      assert %Ash.Query{
               load: [
                 artist: %Ash.Query{
                   load: [albums: %Ash.Query{resource: Cinder.Integration.Album, limit: 3}]
                 }
               ]
             } =
               Embers.load(Cinder.Integration.Album, [
                 %{relationship: [:artist, :albums], limit: 2}
               ])
    end
  end

  describe "for_layout/2" do
    @content %{relationship: :members}
    @cells %{relationship: :members, cells: true}

    test "tables render every entry" do
      assert Embers.for_layout([@content, @cells], :table) == [@content, @cells]
    end

    test "list and grid layouts skip cells entries, with a warning" do
      log =
        capture_log(fn ->
          assert Embers.for_layout([@content, @cells], :list) == [@content]
          assert Embers.for_layout([@content, @cells], :grid) == [@content]
        end)

      assert log =~ "only works in the table layout"
    end
  end

  describe "more_text/1" do
    test "uses the slot's text, defaulting to More…" do
      assert Embers.more_text(%{more: "All members →"}) == "All members →"
      assert Embers.more_text(%{}) == "More…"
    end
  end
end
