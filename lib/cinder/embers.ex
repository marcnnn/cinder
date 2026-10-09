defmodule Cinder.Embers do
  @moduledoc """
  Child rows (sub-rows) for related records: the sparks a record throws off.

  The `<:embers>` slot names a relationship (or a path of relationships), and
  Cinder loads it alongside the collection's own query. Each related record
  is then rendered as its own child row beneath its parent:

  ```heex
  <Cinder.collection resource={MyApp.Team} actor={@current_user}>
    <:col :let={team} field="name" filter sort>{team.name}</:col>
    <:col :let={team} field="lead.name">{team.lead.name}</:col>

    <:embers :let={member} relationship={:members} limit={5} empty="No members yet">
      {member.name} · {member.email}
    </:embers>
  </Cinder.collection>
  ```

  Cinder renders the wrapper around each child row and the slot provides its
  content, so the same slot works in every layout:

  * **Table**: a `<tr>` beneath the parent's row, with the content in a
    full-width cell.
  * **List and grid**: a container inside the item, below the `<:item>`
    content, holding one element per related record.

  ## Column-aligned cells

  With `cells`, the slot renders the child row's `<td>` cells itself, so they
  can line up with the parent's columns:

  ```heex
  <:embers :let={member} relationship={:members} cells>
    <td class="pl-8">{member.name}</td>
    <td>{member.email}</td>
  </:embers>
  ```

  `<td>` cells only make sense in a table, so list and grid layouts skip (and
  don't load) `cells` embers, logging a warning.

  ## Options

  * `relationship` (required): an atom, or a list of atoms to reach through
    other relationships (`[:org, :members]`). To-many hops along the way are
    flattened.
  * `query`: an `Ash.Query` on the related resource used for the load, to
    filter, sort or load further fields of the related records. With a path,
    it applies to the last relationship.
  * `limit`: the most child rows to render per record. Cinder loads one extra
    related record to know whether there are more, and if so renders a `more`
    row after the last child. Overrides any limit set on `query`.
  * `more`: text for the row shown when a record has more related records
    than `limit`. Defaults to "More…".
  * `empty`: text for a row when a record has no related records. Without it,
    such a record gets no child rows at all.
  * `cells`: render the slot as the child row's `<td>` cells (table only).

  In tables, child rows are not clickable and never selectable; when the
  collection is selectable, a `cells` row starts with an empty cell under the
  checkbox column. In list and grid layouts, child rows are part of the item,
  so they are clickable when the item is.

  Filtering on the related records works through the ordinary column and
  filter slots, using dot notation (`field="members.email"`), which filters the
  parent rows by whether any related record matches.

  Child rows render before a `<:row_detail>`.
  """

  use Cinder.Messages

  require Logger

  @doc """
  The `<:embers>` slot entries a layout can render. Tables render all of them;
  list and grid layouts skip `cells` entries, which render `<td>` cells.
  """
  def for_layout(embers_slots, :table), do: embers_slots

  def for_layout(embers_slots, layout) do
    {cells, rest} = Enum.split_with(embers_slots, &cells?/1)

    if cells != [] do
      Logger.warning(
        "Cinder: <:embers cells> renders <td> cells and only works in the table layout; " <>
          "skipping it in the #{layout} layout."
      )
    end

    rest
  end

  @doc """
  Adds the loads for every `<:embers>` slot to the collection's query.
  """
  def load(query, []), do: query

  def load(query, embers_slots) do
    query = Ash.Query.new(query)

    Enum.reduce(embers_slots, query, fn slot, query ->
      path = path!(slot)
      Ash.Query.load(query, load_statement(path, related_query(query.resource, path, slot)))
    end)
  end

  @doc """
  The child rows of `item` for one `<:embers>` slot entry, as
  `{related_records, more?}`, where `more?` says whether `limit` cut any off.
  """
  def children(item, slot) do
    children = item |> walk(path!(slot)) |> List.wrap()

    case limit(slot) do
      nil -> {children, false}
      limit -> {Enum.take(children, limit), length(children) > limit}
    end
  end

  @doc "Whether the slot entry renders its own `<td>` cells."
  def cells?(slot), do: Map.get(slot, :cells, false) == true

  @doc "The text for the row shown when `limit` cut off related records."
  def more_text(slot), do: Map.get(slot, :more) || dgettext("cinder", "More…")

  defp related_query(resource, path, slot) do
    case {Map.get(slot, :query), limit(slot)} do
      {query, nil} ->
        query

      {nil, limit} ->
        resource
        |> Ash.Resource.Info.related(path)
        |> Ash.Query.limit(limit + 1)

      {query, limit} ->
        Ash.Query.limit(query, limit + 1)
    end
  end

  defp limit(slot) do
    case Map.get(slot, :limit) do
      nil ->
        nil

      limit when is_integer(limit) and limit > 0 ->
        limit

      other ->
        raise ArgumentError, "<:embers> limit must be a positive integer, got: #{inspect(other)}"
    end
  end

  defp load_statement([relationship], nil), do: [relationship]
  defp load_statement([relationship], query), do: [{relationship, query}]

  defp load_statement([relationship | rest], query),
    do: [{relationship, load_statement(rest, query)}]

  defp walk(nil, _path), do: nil
  defp walk(%Ash.NotLoaded{}, _path), do: nil
  defp walk(%Ash.ForbiddenField{}, _path), do: nil
  defp walk(value, []), do: value

  defp walk(values, path) when is_list(values) do
    Enum.flat_map(values, &List.wrap(walk(&1, path)))
  end

  defp walk(value, [relationship | rest]), do: walk(Map.get(value, relationship), rest)

  defp path!(%{relationship: relationship}) when is_atom(relationship), do: [relationship]

  defp path!(%{relationship: [_ | _] = path}) do
    if Enum.all?(path, &is_atom/1), do: path, else: invalid!(path)
  end

  defp path!(slot), do: invalid!(Map.get(slot, :relationship))

  defp invalid!(value) do
    raise ArgumentError,
          "<:embers> needs relationship={:name} or relationship={[:through, :name]}, got: " <>
            inspect(value)
  end
end
