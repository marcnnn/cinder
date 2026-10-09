defmodule Cinder.Renderers.Embers do
  @moduledoc """
  Child rows (`<:embers>`) inside a list or grid item. The table renderer
  renders its own `<tr>` child rows.
  """

  use Phoenix.Component

  import Cinder.Renderers.Helpers, only: [embers_for: 2]

  attr :item, :any, required: true
  attr :item_id, :string, required: true
  attr :embers_slot, :list, required: true
  attr :theme, :map, required: true

  def render(assigns) do
    assigns = assign(assigns, :embers, embers_for(assigns, assigns.item))

    ~H"""
    <%= for {ember_slot, children, more?} <- @embers, children != [] or more? or is_binary(ember_slot[:empty]) do %>
      <div class={@theme.ember_container_class} data-key="ember_container_class" data-ember-for={@item_id}>
        <div :for={child <- children} class={@theme.ember_row_class} data-key="ember_row_class">
          {render_slot(ember_slot, child)}
        </div>
        <div :if={more?} class={@theme.ember_more_class} data-key="ember_more_class" data-ember-more-for={@item_id}>
          {Cinder.Embers.more_text(ember_slot)}
        </div>
        <div :if={children == []} class={@theme.ember_empty_class} data-key="ember_empty_class">
          {ember_slot.empty}
        </div>
      </div>
    <% end %>
    """
  end
end
