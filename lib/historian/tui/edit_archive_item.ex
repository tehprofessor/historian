defmodule Historian.TUi.EditArchiveItem do
  @moduledoc false

  alias Historian.TerminalUI.Cursor
  alias Historian.Archive

  import Historian.TUi.ModalView
  import Ratatouille.Constants, only: [key: 1]

  @spacebar key(:space)

  @arrow_up key(:arrow_up)
  @arrow_down key(:arrow_down)

  @enter key(:enter)

  @delete_keys [
    key(:delete),
    key(:backspace),
    key(:backspace2)
  ]

  def maybe_render(%{
        model: %{
          object: %{items: values, name: name},
          element_cursor: element_cursor,
          cursor: cursor
        },
        last_event: :editing_entry
      }) do
    content = if is_list(values), do: Enum.join(values, "\n"), else: values

    name = if is_atom(name), do: ":#{name}", else: name
    edit_dialog_box(name, content, 3, cursor, element_cursor)
  end

  def maybe_render(_) do
    # noop
    nil
  end

  def handle_event(
        {:event, %{key: @arrow_up}},
        {:editing_entry, %{element_cursor: cursor} = edit_item}
      ) do
    {:editing_entry, %{edit_item | element_cursor: Cursor.up(cursor)}}
  end

  def handle_event(
        {:event, %{key: @arrow_down}},
        {:editing_entry, %{element_cursor: cursor} = edit_item}
      ) do
    {:editing_entry, %{edit_item | element_cursor: Cursor.down(cursor)}}
  end

  def handle_event(
        {:event, %{key: key}},
        {:editing_entry, %{element_cursor: %{cursor: 0}} = edit_item}
      )
      when key in @delete_keys do
    term =
      if is_atom(edit_item.object.name),
        do: ":#{edit_item.object.name}",
        else: edit_item.object.name

    new_value = String.slice(term, 0..-2)

    {:editing_entry, %{edit_item | object: %{edit_item.object | name: new_value}}}
  end

  def handle_event(
        {:event, %{key: key}},
        {:editing_entry, %{element_cursor: %{cursor: 1}} = edit_item}
      )
      when key in @delete_keys do
    term = Enum.join(edit_item.object.items, "\n")

    cursor =
      if String.ends_with?(term, "\n") do
        Cursor.up(edit_item.cursor)
      else
        edit_item.cursor
      end

    new_value = String.slice(term, 0..-2) |> String.split("\n")

    {:editing_entry,
     %{edit_item | object: %{edit_item.object | items: new_value}, cursor: cursor}}
  end

  def handle_event(
        {:event, %{key: @enter}},
        {:editing_entry, %{element_cursor: %{cursor: 1}} = edit_item}
      ) do
    term = Enum.join(edit_item.object.items, "\n")
    new_value = String.split(term <> "\n", "\n")
    item_cursor = Cursor.up(edit_item.cursor)

    {:editing_entry,
     %{edit_item | object: %{edit_item.object | items: new_value}, cursor: item_cursor}}
  end

  def handle_event(
        {:event, %{key: @enter}},
        {:editing_entry, %{element_cursor: %{cursor: 2}} = edit_item}
      ) do
    {:editing_entry_cancel, edit_item}
  end

  def handle_event(
        {:event, %{key: @enter}},
        {:editing_entry, %{element_cursor: %{cursor: 3}, object: object, source: source}}
      ) do
    object =
      if is_atom(source.name) and is_binary(object.name) do
        atomized_name = String.trim_leading(object.name, ":") |> String.to_atom()
        %{object | name: atomized_name}
      else
        object
      end

    {:editing_entry_save, Archive.update_value(object, source)}
  end

  def handle_event({:event, %{key: @spacebar}}, {:editing_entry, edit_item}) do
    term = Enum.join(edit_item.object.items, "\n")
    new_value = String.split(term <> " ", "\n")
    {:editing_entry, %{edit_item | object: %{edit_item.object | items: new_value}}}
  end

  def handle_event(
        {:event, %{ch: ch}},
        {:editing_entry, %{element_cursor: %{cursor: 1}} = edit_item}
      )
      when ch > 0 do
    term = Enum.join(edit_item.object.items, "\n")
    new_value = String.split(term <> <<ch::utf8>>, "\n")
    {:editing_entry, %{edit_item | object: %{edit_item.object | items: new_value}}}
  end

  def handle_event(
        {:event, %{ch: ch}},
        {:editing_entry, %{element_cursor: %{cursor: 0}} = edit_item}
      )
      when ch > 0 do
    term =
      if is_atom(edit_item.object.name),
        do: ":#{edit_item.object.name}",
        else: edit_item.object.name

    new_value = term <> <<ch::utf8>>
    {:editing_entry, %{edit_item | object: %{edit_item.object | name: new_value}}}
  end

  def handle_event(_, {:editing_entry, _edit_item} = last_event) do
    last_event
  end
end
