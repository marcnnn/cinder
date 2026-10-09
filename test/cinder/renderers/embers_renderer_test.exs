defmodule Cinder.Renderers.EmbersRendererTest do
  @moduledoc """
  Table renderer output for the `embers` slot: row order, the selection column
  and the empty row.
  """

  use ExUnit.Case, async: true
  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest

  alias Cinder.Renderers.Table, as: TableRenderer

  @data [
    %{id: "1", name: "Alpha", members: [%{name: "Ann"}, %{name: "Ben"}]},
    %{id: "2", name: "Beta", members: []}
  ]

  defp assigns(overrides) do
    col_slot = %{__slot__: :col, field: :name, inner_block: fn _, item -> item.name end}

    Map.merge(
      %{
        id: "test-table",
        theme: Map.merge(Cinder.Theme.default(), %{ember_row_class: "theme-ember"}),
        data: @data,
        columns: [
          %{field: :name, label: "Name", sortable: false, class: nil, slot: col_slot},
          %{field: :name, label: "Again", sortable: false, class: nil, slot: col_slot}
        ],
        filters: %{},
        sort_by: [],
        loading: false,
        error: false,
        loading_message: "Loading...",
        empty_message: "No results",
        error_message: "An error occurred",
        show_filters: false,
        show_pagination: false,
        page: nil,
        page_size_config: %{},
        pagination_mode: :offset,
        myself: nil,
        filters_label: "Filters",
        search_term: "",
        search_enabled: false,
        search_label: "Search",
        search_placeholder: "Search...",
        row_click: nil,
        selectable: false,
        selected_ids: MapSet.new(),
        id_field: :id,
        bulk_action_slots: [],
        embers_slot: [embers_slot()]
      },
      overrides
    )
  end

  defp embers_slot(extra \\ %{}) do
    Map.merge(
      %{
        __slot__: :embers,
        relationship: :members,
        inner_block: fn _, member ->
          assigns = %{member: member}

          ~H"""
          <td class="member">{@member.name}</td>
          """
        end
      },
      extra
    )
  end

  defp render_table(overrides), do: render_component(&TableRenderer.render/1, assigns(overrides))

  defp rows(overrides) do
    overrides
    |> render_table()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("tbody tr")
    |> Enum.map(fn row ->
      {row |> LazyHTML.attribute("data-item-id") |> List.first(),
       row |> LazyHTML.attribute("data-ember-for") |> List.first(),
       row |> LazyHTML.text() |> String.trim()}
    end)
  end

  test "related records follow their parent row, one row each" do
    assert [
             {"1", nil, _},
             {nil, "1", "Ann"},
             {nil, "1", "Ben"},
             {"2", nil, _}
           ] = rows(%{})
  end

  test "a record without related records gets a full-width empty row when asked" do
    html =
      %{embers_slot: [embers_slot(%{empty: "Nobody yet"})]}
      |> render_table()

    cell = html |> LazyHTML.from_fragment() |> LazyHTML.query("tr[data-ember-for='2'] td")

    assert LazyHTML.text(cell) =~ "Nobody yet"
    assert cell |> LazyHTML.attribute("colspan") == ["2"]
  end

  test "ember rows start with an empty cell under the selection column" do
    html =
      %{selectable: true}
      |> render_table()

    cells =
      html
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("tr[data-ember-for='1'] td")
      |> Enum.map(&String.trim(LazyHTML.text(&1)))

    assert ["", "Ann", "", "Ben"] = cells
  end

  test "ember rows carry the theme class and no click handler" do
    html =
      %{row_click: fn item -> Phoenix.LiveView.JS.navigate("/#{item.id}") end}
      |> render_table()

    ember = html |> LazyHTML.from_fragment() |> LazyHTML.query("tr[data-ember-for='1']")

    assert ember |> LazyHTML.attribute("class") |> Enum.all?(&(&1 =~ "theme-ember"))
    assert ember |> LazyHTML.attribute("phx-click") == []
  end

  test "renders no ember rows without the slot" do
    assert [{"1", nil, _}, {"2", nil, _}] = rows(%{embers_slot: []})
  end
end
