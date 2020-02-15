defmodule Historian.TUi.HistoryView do
  alias Historian.TerminalUI.Cursor

  import Historian.Gettext
  import Historian.TUi.Elements
  import Ratatouille.View

  require Logger

  @status_bar_color :white
  @status_bar_bg :magenta

  @txt_buffer_size "buffer size:"
  @txt_copied_line "COPIED LINE!"
  @txt_copied_lines "COPIED LINES!"
  @txt_search "search"
  @txt_selected_line "SELECTED LINE!"
  @txt_viewing_history "VIEWING HISTORY"

  def render(%{
        cursor: screen_cursor,
        data: %{items: items, cursor: %{size: max_length} = cursor, selected_lines: selected_ids},
        last_event: event
      }) do
    selected = Cursor.position(cursor)

    {:ok, window_height} = Ratatouille.Window.fetch(:height)

    top_bar = menu_bar(screen_cursor, 1)

    bottom_bar = history_status_bar(event, max_length)
    viewport_offset_y = viewport_offset(cursor, window_height)

    view(top_bar: top_bar, bottom_bar: bottom_bar) do
      row do
        history_split_view(:ids, :cyan, :black, viewport_offset_y, items, fn
          %{id: id} -> history_item(event, id, id, selected, selected_ids)
        end)

        history_split_view(:values, :cyan, :black, viewport_offset_y, items, fn
          %{id: id, value: value} -> history_item(event, id, value, selected, selected_ids)
        end)
      end
    end
  end

  def history_status_bar(:select_line, _unused) do
    do_history_status_bar(gettext(@txt_selected_line), nil)
  end

  def history_status_bar(:copied_line, _unused) do
    do_history_status_bar(gettext(@txt_copied_line), nil)
  end

  def history_status_bar(:copied_lines, _unused) do
    do_history_status_bar(gettext(@txt_copied_lines), nil)
  end

  def history_status_bar(_default, history_buffer_size) do
    buffer_size_text = gettext(@txt_buffer_size) <> " #{to_string(history_buffer_size)}"
    do_history_status_bar(gettext(@txt_viewing_history), buffer_size_text)
  end

  defp do_history_status_bar(action_text, status_text) do
    navigation_items = history_view_navigation_items(@status_bar_color, @status_bar_bg)

    status_bar_items =
      case maybe_history_status_text(status_text, @status_bar_color, @status_bar_bg) do
        nil -> navigation_items
        text_item -> [text_item | navigation_items]
      end

    status_bar(action_text, @status_bar_color, @status_bar_bg) do
      status_bar_items
    end
  end

  defp maybe_history_status_text(nil, _color, _bg_color) do
    nil
  end

  defp maybe_history_status_text(status_text, color, bg_color) do
    text(
      content: " #{status_text}",
      color: color,
      background: bg_color,
      attributes: []
    )
  end

  defp history_view_navigation_items(color, bg_color) do
    search_text = gettext(@txt_search)

    [
      navigation_item(:quit, color, bg_color),
      navigation_item(:move_down, color, bg_color),
      navigation_item(:move_up, color, bg_color),
      navigation_item(:copy_line, color, bg_color),
      navigation_item(:select_line, color, bg_color),
      navigation_option(search_text, "s", color, bg_color)
    ]
  end
end
