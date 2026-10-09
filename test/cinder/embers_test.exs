defmodule Cinder.EmbersTest do
  use ExUnit.Case, async: true

  alias Cinder.Embers

  describe "children/2" do
    test "returns the loaded relationship" do
      item = %{members: [%{name: "a"}, %{name: "b"}]}

      assert Embers.children(item, %{relationship: :members}) == [%{name: "a"}, %{name: "b"}]
    end

    test "walks a path and flattens to-many hops" do
      item = %{teams: [%{members: [%{name: "a"}]}, %{members: [%{name: "b"}]}]}

      assert Embers.children(item, %{relationship: [:teams, :members]}) ==
               [%{name: "a"}, %{name: "b"}]
    end

    test "wraps a to-one relationship" do
      assert Embers.children(%{lead: %{name: "a"}}, %{relationship: :lead}) == [%{name: "a"}]
    end

    test "treats nil, unloaded and forbidden values as no children" do
      assert Embers.children(%{members: nil}, %{relationship: :members}) == []
      assert Embers.children(%{members: %Ash.NotLoaded{}}, %{relationship: :members}) == []
      assert Embers.children(%{org: nil}, %{relationship: [:org, :members]}) == []

      assert Embers.children(%{members: %Ash.ForbiddenField{}}, %{relationship: :members}) ==
               []
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
  end
end
