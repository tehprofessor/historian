defmodule Historian.TUi.Elements do
  alias Historian.Config
  alias Historian.TerminalUI.Cursor

  import Historian.Gettext
  import Ratatouille.View

  @txt_history_buffer "History Buffer"
  @txt_archives "Archives"

  def column_panel(size, title, color, bg, offset_y, items, display_item_fn) do
    column(size: size) do
      panel title: " #{title} ", height: :fill, color: color, background: bg do
        viewport(offset_y: offset_y) do
          Enum.map(items, display_item_fn)
        end
      end
    end
  end

  def history_item(event, line_id, content, current_selection_id, []) do
    history_item(event, line_id, content, current_selection_id)
  end

  def history_item(event, line_id, content, current_selection_id, selected_ids)
      when is_list(selected_ids) do
    text_color = Config.color(:history_line_multiselect_text_selected, :blue)
    bg_color = Config.color(:history_line_multiselect_background_selected, :black)

    if Enum.member?(selected_ids, line_id) do
      label(content: " #{content} ", color: text_color, background: bg_color, attributes: [:bold])
    else
      history_item(event, line_id, content, current_selection_id)
    end
  end

  def history_item(:copied_lines, selected_id, content, selected_id) do
    copied_line_color = Config.color(:history_line_text, :white)

    label(content: " #{content} ", color: copied_line_color, attributes: [:bold])
  end

  def history_item(:copied_line, selected_id, content, selected_id) do
    copied_line_color = Config.color(:history_line_copied_line_ok, :yellow)
    bg_color = Config.color(:history_line_copied_line_background, :default)

    label(content: " #{content} ", color: copied_line_color, background: bg_color, attributes: [:bold])
  end

  def history_item(:select_search, selected_id, content, selected_id) do
    search_item_matching_text_color = Config.color(:search_item_matching_text_selected, :cyan)
    selected_line_bg = Config.color(:history_current_line_background, :black)

    label(content: " #{content} ", color: search_item_matching_text_color, background: selected_line_bg, attributes: [:bold])
  end

  def history_item(_event, selected_id, content, selected_id) do
    selected_bg_color = Config.color(:history_current_line_background, :black)
    selected_text_color = Config.color(:history_current_line_text, :white)

    label(content: " #{content} ", color: selected_text_color, background: selected_bg_color, attributes: [:bold])
  end

  def history_item(_event, _id, content, _selected) do
    text_color = Config.color(:history_line_text, :white)
    bg_color = Config.color(:history_line_background, :default)

    label(content: " #{content} ", color: text_color, background: bg_color, attributes: [])
  end

  def history_split_view(:ids, color, bg, offset_y, items, display_item_fn) do
    column_panel(1, "Index", color, bg, offset_y, items, display_item_fn)
  end

  def history_split_view(:values, color, bg, offset_y, items, display_item_fn) do
    column_panel(11, "Value", color, bg, offset_y, items, display_item_fn)
  end

  def menu_bar(cursor, _index \\ 0) do
    {:ok, window_width} = Ratatouille.Window.fetch(:width)
    # This is too much padding, but I honestly can't tell if makes any difference.
    history_text = gettext(@txt_history_buffer)
    archives_text = gettext(@txt_archives)
    magic_number = String.length("Historian  [1 #{history_text}] -- [2 #{archives_text}]")
    bar_padding = String.pad_trailing(" ", window_width - magic_number)

    menu_bar_background_color = Config.color(:screen_navigation_background, :black)
    menu_bar_app_name_text_color = Config.color(:screen_navigation_app_name_text, :black)

    menu_bar_app_name_background_color =
      Config.color(:screen_navigation_app_name_background, :cyan)

    menu_bar_text_color = Config.color(:screen_navigation_text, :white)

    menu_bar_items = [
      text(
        content: "  Historian  ",
        background: menu_bar_app_name_background_color,
        color: menu_bar_app_name_text_color,
        attributes: [:bold]
      )
    ]

    history_screen_item =
      screen_navigation(
        history_text,
        1,
        menu_bar_text_color,
        menu_bar_background_color,
        Cursor.selected?(cursor, 0)
      )

    menu_bar_items = [history_screen_item | menu_bar_items]

    menu_bar_items = [
      text(
        content: " |",
        background: menu_bar_background_color,
        color: menu_bar_text_color,
        attributes: []
      )
      | menu_bar_items
    ]

    archive_screen_item =
      screen_navigation(
        archives_text,
        2,
        menu_bar_text_color,
        menu_bar_background_color,
        Cursor.selected?(cursor, 1)
      )

    menu_bar_items = [archive_screen_item | menu_bar_items]

    menu_bar_items = [
      text(
        content: bar_padding,
        background: menu_bar_background_color,
        color: menu_bar_background_color,
        attributes: []
      )
      | menu_bar_items
    ]

    bar do
      label do
        Enum.reverse(menu_bar_items)
      end
    end
  end

  def navigation_item(:copy_line, color, bg) do
    navigation_option(gettext("copy lines"), "y", color, bg)
  end

  def navigation_item(:select_line, color, bg) do
    navigation_option(gettext("select lines"), "space", color, bg)
  end

  def navigation_item(:scroll_up, color, bg) do
    navigation_option(gettext("scroll up"), "k", color, bg)
  end

  def navigation_item(:scroll_down, color, bg) do
    navigation_option(gettext("scroll down"), "j", color, bg)
  end

  def navigation_item(:move_up, color, bg) do
    navigation_option(gettext("move up"), "k", color, bg)
  end

  def navigation_item(:move_down, color, bg) do
    navigation_option(gettext("move down"), "j", color, bg)
  end

  def navigation_item(:quit, color, bg) do
    navigation_option(gettext("quit historian"), "ctrl+d", color, bg)
  end

  def navigation_option(name, selected_binding, color, bg, selected_binding)
      when is_integer(selected_binding) do
    [
      text(content: " [", color: color, background: bg),
      text(content: "#{selected_binding}", color: color, background: bg, attributes: [:bold]),
      text(content: "]", color: color, background: bg),
      text(content: " #{name}", color: color, background: bg)
    ]
  end

  def navigation_option(name, key_binding, color, bg, _selected) when is_integer(key_binding) do
    [
      text(content: " [", color: color, background: bg),
      text(content: "#{key_binding}", color: color, background: bg, attributes: [:bold]),
      text(content: "]", color: color, background: bg),
      text(content: " #{name}", color: color, background: bg)
    ]
  end

  def navigation_option(name, "", color, bg) do
    [
      text(content: " #{name}", color: color, background: bg)
    ]
  end

  def navigation_option(name, key_binding, color, bg) do
    [
      text(content: " (", color: color, background: bg),
      text(content: "#{key_binding}", color: color, background: bg, attributes: [:bold]),
      text(content: ")", color: color, background: bg),
      text(content: " #{name}", color: color, background: bg)
    ]
  end

  def screen_navigation(name, key_binding, color, bg, true = _selected) do
    menu_bar_text_selected_color = Config.color(:screen_navigation_text_selected, :cyan)

    [
      text(content: " [", color: color, background: bg),
      text(
        content: "#{key_binding}",
        color: menu_bar_text_selected_color,
        background: bg,
        attributes: [:bold]
      ),
      text(content: "]", color: color, background: bg),
      text(
        content: " #{name}",
        color: menu_bar_text_selected_color,
        background: bg,
        attributes: [:bold, :underline]
      )
    ]
  end

  def screen_navigation(name, key_binding, color, bg, _not_selected) do
    [
      text(content: " [", color: color, background: bg),
      text(content: "#{key_binding}", color: color, background: bg),
      text(content: "]", color: color, background: bg),
      text(content: " #{name}", color: color, background: bg)
    ]
  end

  def status_bar(action_text, color, background, do: block) do
    {:ok, window_width} = Ratatouille.Window.fetch(:width)
    # This is too much padding, but I honestly can't tell if makes any difference.
    magic_number = String.length(action_text)
    bar_padding = String.pad_trailing(" ", window_width - magic_number)

    bar do
      label(background: :default) do
        text(content: " #{action_text} »", color: color, background: background, attributes: [:bold])
        block
        text(content: bar_padding, color: color, background: background)
      end
    end
  end

  # This should go somewhere else but it's minor
  def viewport_offset(%{cursor: cursor}, window_height) do
    viewport_offset(cursor, window_height)
  end

  def viewport_offset(cursor, window_height) do
    scroll_start = div(window_height, 2)
    max(cursor - scroll_start, 0)
  end
end
