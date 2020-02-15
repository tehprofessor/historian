defmodule Historian.TUi.Search do
  alias Historian.TerminalUI.Cursor

  import Historian.Gettext
  import Historian.TUi.Elements
  import Ratatouille.View

  @copied_line "COPIED LINE!"
  @navigating_results "NAVIGATING RESULTS"
  @searching "SEARCHING"
  @search "Search"

  def render(%{
    cursor: screen_cursor,
    data: %{items: items, term: term, pattern: pattern, cursor: %{size: size} = cursor},
        last_event: :copied_line
      }) do
    top_bar = menu_bar(screen_cursor, 0)
    bottom_bar = search_status_bar(:select_search, size, gettext(@copied_line))
    %{id: selected} = Cursor.value_at(items, cursor)

    {:ok, window_height} = Ratatouille.Window.fetch(:height)

    viewport_offset_y = viewport_offset(0, window_height)

    view(top_bar: top_bar, bottom_bar: bottom_bar) do
      search_bar(term)

      row do
        history_split_view(:ids, :cyan, :black, viewport_offset_y, items, fn
          %{id: id} -> history_item(nil, id, id, selected)
        end)

        history_split_view(:values, :cyan, :black, viewport_offset_y, items, fn
          %{id: id, value: value} ->
            search_item({:select_search, id, selected}, value, term, pattern)
        end)
      end
    end
  end

  def render(%{
    cursor: screen_cursor,
    data: %{items: items, term: term, pattern: pattern, cursor: %{size: size} = cursor},
        last_event: :select_search
      }) do
    top_bar = menu_bar(screen_cursor, 0)
    bottom_bar = search_status_bar(:select_search, size, gettext(@navigating_results))
    %{id: selected} = Cursor.value_at(items, cursor)

    {:ok, window_height} = Ratatouille.Window.fetch(:height)

    viewport_offset_y = viewport_offset(0, window_height)

    view(top_bar: top_bar, bottom_bar: bottom_bar) do
      search_bar(term)

      row do
        history_split_view(:ids, :cyan, :black, viewport_offset_y, items, fn
          %{id: id} -> history_item(nil, id, id, selected)
        end)

        history_split_view(:values, :cyan, :black, viewport_offset_y, items, fn
          %{id: id, value: value} ->
            search_item({:select_search, id, selected}, value, term, pattern)
        end)
      end
    end
  end

  def render(%{
    cursor: screen_cursor,
    data: %{items: items, cursor: %{size: size}, term: term, pattern: pattern},
        last_event: _
      }) do
    top_bar = menu_bar(screen_cursor, 0)
    bottom_bar = search_status_bar(:searching, size, gettext(@searching))

    {:ok, window_height} = Ratatouille.Window.fetch(:height)

    viewport_offset_y = viewport_offset(0, window_height)

    view(top_bar: top_bar, bottom_bar: bottom_bar) do
      search_bar(term)

      row do
        history_split_view(:ids, :cyan, :black, viewport_offset_y, items, fn
          %{id: id} -> history_item(nil, id, id, 99999)
        end)

        history_split_view(:values, :cyan, :black, viewport_offset_y, items, fn
          %{value: value} -> search_item(nil, value, term, pattern)
        end)
      end
    end
  end

  def search_bar(term) do
    title = gettext(@search)

    row do
      column(size: 12) do
        panel title: title, background: :black do
          label(content: " > " <> term)
        end
      end
    end
  end

  def search_status_bar(:select_search, _number_of_results, action_text) do
    status_bar_items = [
      navigation_option(gettext("move down"), "j", :black, :yellow),
      navigation_option(gettext("move up"), "k", :black, :yellow),
      navigation_option(gettext("copy line"), "y", :black, :yellow),
      navigation_option(gettext("edit search"), "e", :black, :yellow)
    ]

    status_bar(action_text, :black, :yellow) do
      status_bar_items
    end
  end

  def search_status_bar(:searching, number_of_results, action_text) do
    status_text =
      gettext("Found") <>
        " #{number_of_results} " <>
        ngettext("item matching query", "items matching query", number_of_results)

    nav_text = gettext("Press [enter] to navigate results")

    status_bar_items = [
      text(
        content: status_text,
        color: :black,
        background: :yellow
      ),
      navigation_option(nav_text, "", :black, :yellow)
    ]

    status_bar(action_text, :black, :yellow) do
      status_bar_items
    end
  end

  def search_item(_event, content, "", _pattern) do
    label do
      text(content: "#{content}")
    end
  end

  def search_item({:select_search, selected_id, selected_id}, content, term, _pattern) do
    do_search_item(content, term, [attributes: [:bold]], color: :cyan, attributes: [:bold])
  end

  def search_item({:select_search, _id, _selected_id}, content, term, _pattern) do
    do_search_item(content, term, [], color: :cyan)
  end

  def search_item(_event, content, term, _pattern) do
    do_search_item(content, term, [], color: :cyan, attributes: [:bold])
  end

  defp do_search_item(content, term, text_attrs, selection_attrs) do
    parts =
      to_string(content)
      |> String.split(term)
      |> Enum.map(&text_string(&1, text_attrs))
      |> Enum.intersperse(text_string(term, selection_attrs))

    label do
      parts
    end
  end

  defp text_string(value, attributes) do
    attrs = Keyword.get(attributes, :attributes, [])
    color = Keyword.get(attributes, :color, :default)
    text(content: value, color: color, attributes: attrs)
  end
end
