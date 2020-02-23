defmodule Historian.TUi.Search do
  @moduledoc """
  This module is awful, thar be dragons and terrible nightmares lurking in here.

  TODO/FIXME: Slay dragons, allow hopes and dreams again.
  """
  alias Historian.Config
  alias Historian.TerminalUI.Cursor

  import Historian.Gettext
  import Historian.TUi.Elements
  import Ratatouille.View

  @copied_line "COPIED LINE!"
  @navigating_results "NAVIGATING RESULTS"
  @search "Search"
  @searching "SEARCHING"

  def render(%{
        cursor: screen_cursor,
        data: %{items: items, term: term, pattern: pattern, cursor: %{size: size} = cursor},
        last_event: last_event
      })
      when last_event in [:select_search, :copied_line] do
    status_bar_text =
      if last_event == :select_search,
        do: gettext(@navigating_results),
        else: gettext(@copied_line)

    status_bar_details = {:select_search, status_bar_text, size}

    %{id: selected} = Cursor.value_at(items, cursor)
    display_search_index = fn %{id: id} -> history_item(:select_search, id, id, selected) end

    display_search_value = fn %{id: id, value: value} ->
      search_item({:select_search, id, selected}, value, term, pattern)
    end

    search_view(
      screen_cursor,
      cursor,
      status_bar_details,
      term,
      items,
      display_search_index,
      display_search_value
    )
  end

  def render(%{
        cursor: screen_cursor,
        data: %{items: items, cursor: %{size: size} = cursor, term: term, pattern: pattern},
        last_event: _
      }) do
    status_bar_details = {:searching, gettext(@searching), size}

    display_search_index = fn %{id: id} -> history_item(nil, id, id, 9_999_999) end
    display_search_value = fn %{value: value} -> search_item(nil, value, term, pattern) end

    search_view(
      screen_cursor,
      cursor,
      status_bar_details,
      term,
      items,
      display_search_index,
      display_search_value
    )
  end

  def search_bar(term) do
    title = gettext(@search)

    panel_title_text_color = Config.color(:history_split_view_panel_title_text, :cyan)
    panel_title_background_color = Config.color(:history_split_view_panel_background, :black)

    row do
      column(size: 12) do
        panel title: " #{title} ",
              color: panel_title_text_color,
              background: panel_title_background_color do
          label(content: " > " <> term)
        end
      end
    end
  end

  def search_status_bar(event, number_of_results, action_text) do
    bar_background_color = Config.color(:search_status_bar_background, :yellow)
    bar_text_color = Config.color(:search_status_bar_text, :black)

    search_status_bar(event, number_of_results, action_text, bar_text_color, bar_background_color)
  end

  def search_status_bar(:select_search, _number_of_results, action_text, color, bg_color) do
    status_bar_items = [
      navigation_option(gettext("move down"), "j", color, bg_color),
      navigation_option(gettext("move up"), "k", color, bg_color),
      navigation_option(gettext("copy line"), "y", color, bg_color),
      navigation_option(gettext("edit search term"), "e", color, bg_color),
      navigation_option(gettext("exit search (view history)"), "s", color, bg_color)
    ]

    status_bar(action_text, color, bg_color) do
      status_bar_items
    end
  end

  def search_status_bar(:searching, number_of_results, action_text, color, bg_color) do
    status_text =
      gettext(" Found") <>
        " #{number_of_results} " <>
        ngettext("item matching query", "items matching query", number_of_results)

    nav_text = gettext("Press [enter] to navigate results")

    status_bar_items = [
      text(
        content: status_text,
        color: color,
        background: bg_color
      ),
      navigation_option(nav_text, "", color, bg_color)
    ]

    status_bar(action_text, color, bg_color) do
      status_bar_items
    end
  end

  def search_item(_event, content, "", _pattern) do
    label do
      text(content: "#{content}")
    end
  end

  def search_item({:select_search, selected_id, selected_id}, content, term, _pattern) do
    search_item_matching_text_color = Config.color(:search_item_matching_text_selected, :cyan)
    selected_line_bg_color = Config.color(:history_current_line_background, :black)
    line_text_color = Config.color(:history_current_line_text, :black)

    do_search_item(
      content,
      selected_line_bg_color,
      term,
      [color: line_text_color, attributes: []],
      color: search_item_matching_text_color,
      attributes: [:bold]
    )
  end

  def search_item({:select_search, _id, _selected_id}, content, term, _pattern) do
    search_item_matching_text_color = Config.color(:search_item_matching_text, :cyan)
    line_bg_color = Config.color(:history_line_background, :default)

    do_search_item(content, line_bg_color, term, [], color: search_item_matching_text_color)
  end

  def search_item(_event, content, term, _pattern) do
    search_item_matching_text_color = Config.color(:search_item_matching_text, :cyan)
    line_bg_color = Config.color(:history_line_background, :default)

    do_search_item(content, line_bg_color, term, [],
      color: search_item_matching_text_color,
      attributes: [:bold]
    )
  end

  defp do_search_item(content, line_bg_color, term, text_attrs, selection_attrs) do
    parts =
      to_string(content)
      |> String.split(term)
      |> Enum.map(&text_string(&1, text_attrs))
      |> Enum.intersperse(text_string(term, selection_attrs))

    padding = text_string(" ", text_attrs)

    parts = [padding, parts, padding]

    label(background: line_bg_color) do
      parts
    end
  end

  # I know...this is awful.
  defp search_view(
         screen_cursor,
         cursor,
         {status_bar_event, status_bar_text, size},
         term,
         items,
         display_search_index,
         display_search_value
       ) do
    panel_title_text_color = Config.color(:history_split_view_panel_title_text, :cyan)
    panel_title_background_color = Config.color(:history_split_view_panel_background, :black)

    bottom_bar = search_status_bar(status_bar_event, size, status_bar_text)
    top_bar = menu_bar(screen_cursor, 0)

    {:ok, window_height} = Ratatouille.Window.fetch(:height)
    vertical_offset = viewport_offset(cursor, window_height)

    view(top_bar: top_bar, bottom_bar: bottom_bar) do
      search_bar(term)

      row do
        history_split_view(
          :ids,
          panel_title_text_color,
          panel_title_background_color,
          vertical_offset,
          items,
          display_search_index
        )

        history_split_view(
          :values,
          panel_title_text_color,
          panel_title_background_color,
          vertical_offset,
          items,
          display_search_value
        )
      end
    end
  end

  defp text_string(value, attributes) do
    attrs = Keyword.get(attributes, :attributes, [])
    color = Keyword.get(attributes, :color, :default)
    text(content: value, color: color, attributes: attrs)
  end
end
