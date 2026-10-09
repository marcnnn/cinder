defmodule Cinder.Embers do
  @moduledoc """
  Related records rendered as rows beneath their parent row — the sparks a
  record throws off.

  The table layout's `<:embers>` slot names a relationship (or a path of
  relationships), and Cinder loads it alongside the collection's own query.
  Each related record then gets its own `<tr>` directly beneath its parent's
  row, and the slot renders that row's `<td>` cells, so they can line up with
  the parent's columns:

  ```heex
  <Cinder.collection resource={MyApp.Team} actor={@current_user}>
    <:col :let={team} field="name" filter sort>{team.name}</:col>
    <:col :let={team} field="lead.name">{team.lead.name}</:col>

    <:embers :let={member} relationship={:members} empty="No members yet">
      <td class="pl-8">{member.name}</td>
      <td>{member.email}</td>
    </:embers>
  </Cinder.collection>
  ```

  ## Options

  * `relationship` (required) — an atom, or a list of atoms to reach through
    other relationships (`[:org, :members]`). To-many hops along the way are
    flattened.
  * `query` — an `Ash.Query` on the related resource used for the load, to
    filter, sort or load further fields of the related records. With a path,
    it applies to the last relationship.
  * `empty` — text for a full-width row when a record has no related records.
    Without it, such a record gets no ember rows at all.

  When the collection is selectable, each ember row starts with an empty cell
  under the checkbox column. Ember rows are not clickable and never selectable.

  Filtering on the related records works through the ordinary column and
  filter slots, using dot notation (`field="members.email"`), which filters the
  parent rows by whether any related record matches.

  Ember rows render before a `<:row_detail>` row. List and grid layouts ignore
  the slot and do not load the relationship.
  """

  require Ash.Query

  @doc """
  Adds the loads for every `<:embers>` slot to the collection's query.
  """
  def load(query, []), do: query

  def load(query, embers_slots) do
    Enum.reduce(embers_slots, Ash.Query.new(query), fn slot, query ->
      Ash.Query.load(query, load_statement(path!(slot), Map.get(slot, :query)))
    end)
  end

  @doc """
  The related records of `item` for one `<:embers>` slot entry.
  """
  def children(item, slot) do
    item
    |> walk(path!(slot))
    |> List.wrap()
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
