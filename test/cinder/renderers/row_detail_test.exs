defmodule Cinder.Renderers.RowDetailTest do
  @moduledoc """
  Tests for the table layout's `row_detail` slot: a full-width row rendered
  beneath each record's row.
  """

  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  alias Cinder.Renderers.Table, as: TableRenderer
  alias Phoenix.LiveView.JS

  @data [
    %{id: "1", name: "Alpha", note: "first note"},
    %{id: "2", name: "Beta", note: "second note"}
  ]

  defp table_assigns do
    col_slot = %{__slot__: :col, field: :name, inner_block: fn _, item -> item.name end}

    %{
      id: "test-table",
      theme:
        Cinder.Theme.default()
        |> Map.merge(%{
          row_detail_class: "theme-detail-row",
          row_detail_cell_class: "theme-detail-cell"
        }),
      data: @data,
      columns: [
        %{field: :name, label: "Name", sortable: false, class: nil, slot: col_slot},
        %{field: :name, label: "Again", sortable: false, class: nil, slot: col_slot}
      ],
      col_slot: [col_slot],
      filters: %{},
      sort_by: [],
      sort_label: "Sort",
      loading: false,
      error: false,
      loading_message: "Loading...",
      empty_message: "No results",
      error_message: "An error occurred",
      show_filters: false,
      show_sort: false,
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
      bulk_action_slots: []
    }
  end

  defp row_detail_slot do
    [%{__slot__: :row_detail, inner_block: fn _, item -> "detail: #{item.note}" end}]
  end

  defp render_table(assigns), do: render_component(&TableRenderer.render/1, assigns)

  defp body_rows(html) do
    html |> LazyHTML.from_fragment() |> LazyHTML.query("tbody tr") |> Enum.to_list()
  end

  defp attr(node, name), do: node |> LazyHTML.attribute(name) |> List.first()

  test "renders a detail row directly beneath each record's row" do
    html = render_table(Map.put(table_assigns(), :row_detail_slot, row_detail_slot()))

    rows = body_rows(html)
    assert length(rows) == 4

    assert [
             {"1", nil},
             {nil, "1"},
             {"2", nil},
             {nil, "2"}
           ] = Enum.map(rows, &{attr(&1, "data-item-id"), attr(&1, "data-row-detail-for")})

    assert rows |> Enum.at(1) |> LazyHTML.text() =~ "detail: first note"
    assert rows |> Enum.at(3) |> LazyHTML.text() =~ "detail: second note"
  end

  test "the detail cell spans every column and carries the theme classes" do
    html = render_table(Map.put(table_assigns(), :row_detail_slot, row_detail_slot()))

    detail = html |> LazyHTML.from_fragment() |> LazyHTML.query("tr[data-row-detail-for='1']")
    assert attr(detail, "class") =~ "theme-detail-row"

    cell = LazyHTML.query(detail, "td")
    assert attr(cell, "colspan") == "2"
    assert attr(cell, "class") =~ "theme-detail-cell"
  end

  test "the detail cell also spans the selection checkbox column" do
    assigns =
      table_assigns()
      |> Map.merge(%{row_detail_slot: row_detail_slot(), selectable: true})

    html = render_table(assigns)

    cell =
      html |> LazyHTML.from_fragment() |> LazyHTML.query("tr[data-row-detail-for='1'] td")

    assert attr(cell, "colspan") == "3"
  end

  test "the detail row does not receive the row click handler" do
    assigns =
      table_assigns()
      |> Map.merge(%{
        row_detail_slot: row_detail_slot(),
        row_click: fn item -> JS.navigate("/items/#{item.id}") end
      })

    doc = assigns |> render_table() |> LazyHTML.from_fragment()

    assert doc |> LazyHTML.query("tr[data-item-id='1']") |> attr("phx-click")
    refute doc |> LazyHTML.query("tr[data-row-detail-for='1']") |> attr("phx-click")
  end

  test "renders no detail rows without the slot" do
    html = render_table(table_assigns())

    assert length(body_rows(html)) == 2
    refute html =~ "data-row-detail-for"
  end

  test "renders no detail rows in the error state" do
    assigns =
      table_assigns()
      |> Map.merge(%{row_detail_slot: row_detail_slot(), error: true})

    html = render_table(assigns)

    refute html =~ "data-row-detail-for"
    assert html =~ "An error occurred"
  end
end
