defmodule Historian.TUi.ArchiveView do
  alias Historian.TerminalUI.Cursor
  alias Historian.TUi.ArchiveItemForm

  import Historian.Gettext
  import Historian.TUi.Elements
  import Ratatouille.View

  @status_bar_color :black
  @status_bar_bg :green

  @txt_archive_col_name "Name"
  @txt_archive_col_value "Value"

  @txt_updated_entry "UPDATED ENTRY!"
  @txt_editing_entry "EDITING ENTRY!"
  @txt_creating_entry "CREATING ENTRY!"
  @txt_copied_entry "COPIED ENTRY!"
  @txt_viewing_archive "VIEWING ARCHIVE"

  @txt_total_entries "total entries:"
  @txt_successfully_updated "Successfully updated:"
  @txt_cancel_editing "cancel editing --"
  @txt_save_changes "save any changes --"
  @txt_type_or_delete "type or delete --"
  @txt_use_arrow_to_change_fields "use arrows to change fields"
  @txt_edit_entry "edit entry"
  @txt_new_entry "new entry"
  @txt_cancel_new_entry "cancel without saving --"

  def render(%{cursor: screen_cursor, data: %{items: [], cursor: cursor} = _model, last_event: event}) do
    {event, event_msg} = do_event(event)
    max_length = cursor.size

    {:ok, window_height} = Ratatouille.Window.fetch(:height)

    top_bar = menu_bar(screen_cursor, 1)

    bottom_bar =
      case event do
        :updated_entry ->
          update_text = gettext(@txt_successfully_updated) <> " #{inspect(event_msg)}"
          archive_status_bar(event, update_text)


        :new_entry ->
          archive_status_bar(event, editing_status_text(event, event_msg.element_cursor))

        :editing_entry ->
          archive_status_bar(event, editing_status_text(event, event_msg.element_cursor))

        _ ->
          archive_status_bar(event, max_length)
      end

    viewport_offset_y = viewport_offset(cursor, window_height)

    view(top_bar: top_bar, bottom_bar: bottom_bar) do
      row do
        archive_column(:ids, :cyan, :black, viewport_offset_y, [%{items: "", name: ""}], fn
          %{name: name} -> archive_item(event, name, name, "")
        end)

        archive_column(:values, :cyan, :black, viewport_offset_y, [%{items: "", name: ""}], fn
          %{name: name, items: items} when is_list(items) ->
            value = Enum.join(items)
            archive_item(event, name, value, "")

          %{name: name, items: value} ->
            archive_item(event, name, value, "")
        end)
      end

      ArchiveItemForm.maybe_render(%{model: event_msg, last_event: event})
    end
  end

  def render(%{cursor: screen_cursor, data: %{items: items, cursor: cursor} = _model, last_event: event}) do
    {event, event_msg} = do_event(event)
    %{name: selected} = Cursor.value_at(items, cursor)
    max_length = cursor.size

    {:ok, window_height} = Ratatouille.Window.fetch(:height)

    top_bar = menu_bar(screen_cursor, 1)

    bottom_bar =
      case event do
        :updated_entry ->
          update_text = gettext(@txt_successfully_updated) <> " #{inspect(event_msg)}"
          archive_status_bar(event, update_text)

        :new_entry ->
          archive_status_bar(event, editing_status_text(event, event_msg.element_cursor))

        :editing_entry ->
          archive_status_bar(event, editing_status_text(event, event_msg.element_cursor))

        _ ->
          archive_status_bar(event, max_length)
      end

    viewport_offset_y = viewport_offset(cursor, window_height)

    view(top_bar: top_bar, bottom_bar: bottom_bar) do
      row do
        archive_column(:ids, :cyan, :black, viewport_offset_y, items, fn
          %{name: name} -> archive_item(event, name, name, selected)
        end)

        archive_column(:values, :cyan, :black, viewport_offset_y, items, fn
          %{name: name, items: items} when is_list(items) ->
            value = Enum.join(items)
            archive_item(event, name, value, selected)

          %{name: name, items: value} ->
            archive_item(event, name, value, selected)
        end)
      end

      ArchiveItemForm.maybe_render(%{model: event_msg, last_event: event})
    end
  end

  defp archive_item(_event, selected_name, value, selected_name) do
    label(content: "#{value}", attributes: [:bold])
  end

  defp archive_item(_event, _name, value, _selected) do
    label(content: "#{value}", attributes: [])
  end

  defp archive_column(:ids, color, bg, offset_y, items, display_item_fn) do
    column_panel(2, gettext(@txt_archive_col_name), color, bg, offset_y, items, display_item_fn)
  end

  defp archive_column(:values, color, bg, offset_y, items, display_item_fn) do
    column_panel(10, gettext(@txt_archive_col_value), color, bg, offset_y, items, display_item_fn)
  end

  defp archive_status_bar(:updated_entry, status_message) do
    do_archive_status_bar(:updated_entry, gettext(@txt_updated_entry), status_message)
  end

  defp archive_status_bar(:new_entry, status_message) do
    do_archive_status_bar(:new_entry, gettext(@txt_creating_entry), status_message)
  end

  defp archive_status_bar(:editing_entry, status_message) do
    do_archive_status_bar(:editing_entry, gettext(@txt_editing_entry), status_message)
  end

  defp archive_status_bar(:copied_line, _unused) do
    do_archive_status_bar(nil, gettext(@txt_copied_entry), nil)
  end

  defp archive_status_bar(_default, archive_size) do
    subtext = gettext(@txt_total_entries) <> " " <> "#{to_string(archive_size)}"

    do_archive_status_bar(
      nil,
      gettext(@txt_viewing_archive),
      subtext
    )
  end

  defp editing_status_text(event, cursor) do
    case {cursor, event} do
      {%{cursor: 1}, :new_entry} -> gettext(@txt_cancel_new_entry)
      {%{cursor: 1}, :editing_entry} -> gettext(@txt_cancel_editing)
      {%{cursor: 2}, _} -> gettext(@txt_save_changes)
      _ -> gettext(@txt_type_or_delete)
    end
  end

  defp do_event(event_msg) do
    case event_msg do
      {event, msg} -> {event, msg}
      event -> {event, nil}
    end
  end

  defp do_archive_status_bar(event, action_text, status_text) do
    navigation_items = navigation_items(event, @status_bar_color, @status_bar_bg)

    status_bar_items =
      case maybe_archive_status_text(status_text, @status_bar_color, @status_bar_bg) do
        nil -> navigation_items
        text_item -> [text_item | navigation_items]
      end

    status_bar(action_text, @status_bar_color, @status_bar_bg) do
      status_bar_items
    end
  end

  defp maybe_archive_status_text(nil, _color, _bg_color) do
    nil
  end

  defp maybe_archive_status_text(status_text, color, bg_color) do
    text(
      content: " #{status_text}",
      color: color,
      background: bg_color,
      attributes: []
    )
  end

  defp navigation_items(:updated_entry, _color, _bg_color) do
    []
  end

  defp navigation_items(:editing_entry, color, bg_color) do
    [
      navigation_option(@txt_use_arrow_to_change_fields, "↑ ↓", color, bg_color)
    ]
  end

  defp navigation_items(:new_entry, color, bg_color) do
    [
      navigation_option(@txt_use_arrow_to_change_fields, "↑ ↓", color, bg_color)
    ]
  end

  defp navigation_items(_event, color, bg_color) do
    [
      navigation_item(:quit, color, bg_color),
      navigation_item(:move_down, color, bg_color),
      navigation_item(:move_up, color, bg_color),
      navigation_item(:copy_line, color, bg_color),
      navigation_option(gettext(@txt_edit_entry), "e", color, bg_color),
      navigation_option(gettext(@txt_new_entry), "n", color, bg_color)
    ]
  end
end
