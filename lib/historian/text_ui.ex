defmodule Historian.TextUI do
  @moduledoc """
  Functions for outputting text directly to the terminal, i.e. the opposite of the TUI.
  """

  alias Historian.{Archive, History}

  import Historian.Gettext

  @txt_id_col_header "id"
  @txt_name_col_header "name"
  @txt_output_for_archive "Output for archive"
  @txt_output_for_lines "Output for lines"
  @txt_no_entry_for "No entry for"
  @txt_search_results_for "Search results for"
  @txt_viewing_page "Viewing page"
  @txt_value_col_header "value"

  # Looks like teal + cyan?
  # @search_color_term_label IO.ANSI.color(1, 5, 3)

  @table_decoration_wrap "+"
  @table_decoration_separator_rows "-"
  @table_decoration_separator_cols "|"

  def search_results(%History{items: results}, term) do
    search_results(results, term)
  end

  def search_results(results, term) do
    results_table = highlight_matching_lines(results, term) |> table()
    [
      gettext(@txt_search_results_for),
      " #{term}:\n",
      results_table
    ]
  end

  def history_item(nil, _colorize, _pretty_print) do
    ""
  end

  def history_item([%History.Item{} | _rest] = items, false, false) do
    join_lines(items)
  end

  def archive_item(nil, nil, _colorize, _pretty_print) do
    ""
  end

  def archive_item(%Archive.Item{items: items}, nil, false, false) do
    join_lines(items)
  end

  def archive_item(nil, name, _colorize, _pretty_print) do
    gettext(@txt_no_entry_for) <> " #{inspect(name)}"
  end

  def archive_item(%Archive.Item{items: items}, name, colorize, pretty_print) do
    lines = join_lines(items)
    output = if pretty_print, do: Code.format_string!(lines), else: lines

    archive_item(output, "#{name}", colorize)
  end

  def archive_item(output, name, false = _colorize) do
    archive_text = gettext(@txt_output_for_archive) <> " #{name}:"
    archive_text <> "\n" <> output
  end

  def archive_item(output, name, true = _colorize) do
    archive_text = gettext(@txt_output_for_archive) <> " "

    IO.ANSI.format([
      :yellow,
      :bright,
      archive_text,
      :cyan,
      name,
      :yellow,
      ":",
      :reset,
      :bright,
      "\n",
      output
    ]) |> IO.iodata_to_binary()
  end

  def page(output, indexes, colorize \\ false)

  def page(output, page_number, false) do
    gettext(@txt_viewing_page) <> " #{page_number}:\n" <> table(output)
  end

  def page(output, page_number, true) do
    gettext(@txt_viewing_page) <> " #{page_number}:\n" <> table(output)
  end

  def lines(output, indexes, colorize \\ false)

  def lines(output, indexes, false) do
    lines = inspect(indexes)
    gettext(@txt_output_for_lines) <> " #{lines}:" <> "\n----\n" <> output <> "\n----\n"
  end

  def lines(output, indexes, true) do
    label_text = gettext(@txt_output_for_lines) <> " "
    lines = "[" <> (Enum.map(indexes, &to_string/1) |> Enum.join(", ") |> to_string()) <> "]"

    IO.ANSI.format_fragment([
      :yellow,
      :bright,
      label_text,
      :cyan,
      lines,
      :yellow,
      ":",
      :reset,
      :bright,
      "\n----\n",
      :reset,
      output,
      :bright,
      "\n----"
    ])
    |> IO.iodata_to_binary()
  end

  def table([]) do
    """
    +------------------+
    |     [empty]      |
    +------------------+
    """
  end

  def table(%History{items: lines}) do
    table(lines)
  end

  def table([%Archive.Item{} | _rest] = lines) do
    id_col_header = gettext(@txt_name_col_header)
    value_col_header = gettext(@txt_value_col_header)
    value_header_length = String.length(value_col_header) + 1
    id_header_length = String.length(id_col_header)

    line_data = Enum.map(lines, fn
      %{items: value, name: name} when is_bitstring(value)->
        value = String.replace(value, "\n", "\\n")
        value_length = String.length(value)
        %{id: to_string(name), value: value, length: value_length}
      %{items: items, name: name} ->
        value = Enum.map(items, &String.replace(&1, "\n", "\\n")) |> Enum.join("\\n")
        %{id: to_string(name), value: value, length: String.length(value)}
    end)

    max_line_length = Enum.max_by(line_data, &(&1.length)) |> Map.get(:length)

    max_number_of_digits = Enum.map(line_data, &String.length(&1.id)) |> Enum.max()
    max_id_col_length = max(max_number_of_digits, id_header_length)

    padding_size = 2
    padding = String.duplicate(" ", padding_size)

    horizontal_separator_length = max_line_length + max_id_col_length + padding_size * 4

    table_rows =
      Enum.map(line_data, fn %{id: index, value: line, length: line_length} ->
        table_row(padding, index, line, line_length, max_id_col_length, max_line_length)
      end)

    horizontal_separator = [
      @table_decoration_wrap,
      String.duplicate(@table_decoration_separator_rows, horizontal_separator_length),
      @table_decoration_wrap,
      "\n"
    ]

    header =
      table_row(
        padding,
        id_col_header,
        value_col_header,
        value_header_length,
        max_id_col_length,
        max_line_length
      )

    [
      horizontal_separator,
      header,
      horizontal_separator,
      table_rows,
      horizontal_separator
    ]
    |> IO.iodata_to_binary()
  end

  def table(lines) do
    id_col_header = gettext(@txt_id_col_header)
    value_col_header = gettext(@txt_value_col_header)
    value_header_length = String.length(value_col_header) + 1
    id_header_length = String.length(id_col_header)

    max_line_length = Enum.map(lines, &(&1.__meta__.length)) |> Enum.max()
    max_number_of_digits = Enum.map(lines, &(&1.id)) |> Enum.max() |> to_string() |> String.length()
    max_id_col_length = max(max_number_of_digits, id_header_length)

    padding_size = 2
    padding = String.duplicate(" ", padding_size)

    horizontal_separator_length = max_line_length + max_id_col_length + padding_size * 4

    table_rows =
      Enum.map(lines, fn %{id: index, value: line, __meta__: %{length: line_length}} ->
        table_row(padding, index, line, line_length, max_id_col_length, max_line_length)
      end)

    horizontal_separator = [
      @table_decoration_wrap,
      String.duplicate(@table_decoration_separator_rows, horizontal_separator_length),
      @table_decoration_wrap,
      "\n"
    ]

    header =
      table_row(
        padding,
        id_col_header,
        value_col_header,
        value_header_length,
        max_id_col_length,
        max_line_length
      )

    [
      horizontal_separator,
      header,
      horizontal_separator,
      table_rows,
      horizontal_separator
    ]
    |> IO.iodata_to_binary()
  end

  defp col_padding(maximum, amount) do
    String.duplicate(" ", max(maximum - amount, 0))
  end

  defp fill_table_row(padding, id, extra_index_padding, value, extra_value_padding) do
    [
      @table_decoration_separator_cols,
      padding,
      extra_index_padding,
      id,
      padding,
      @table_decoration_separator_cols,
      padding,
      value,
      extra_value_padding,
      padding,
      @table_decoration_separator_cols,
      "\n"
    ]
  end

  defp highlight_matching_lines(matching_items, term) do
    # We cal `IO.iodata_to_binary/1` here so we can substitute the original string with highlighted one.
    highlighted =
      [IO.ANSI.color(1, 5, 3), :bright, term, :reset]
      |> IO.ANSI.format_fragment()
      |> IO.iodata_to_binary()

    Enum.map(matching_items, &highlighted_term(&1, term, highlighted))
  end

  defp highlighted_term(%{value: value} = item, term, highlighted) do
    %{item | value: String.replace(value, term, highlighted)}
  end

  defp join_lines(%Archive.Item{items: items}) do
    join_lines(items)
  end

  defp join_lines([%History.Item{} | _rest] = items) do
    items
    |> Enum.map(&Map.get(&1, :value))
    |> join_lines()
  end

  defp join_lines(items) when is_list(items) do
    Enum.join(items, "\n")
  end

  defp join_lines(item) do
    item
  end

  defp table_row(padding, index, value, value_length, max_index_length, max_value_length) do
    index_string = to_string(index)
    index_digits = index_string |> String.length()

    extra_index_padding = col_padding(max_index_length, index_digits)
    extra_line_padding = col_padding(max_value_length, value_length)

    fill_table_row(padding, index_string, extra_index_padding, value, extra_line_padding)
  end
end
