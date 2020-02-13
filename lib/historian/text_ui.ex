defmodule Historian.TextUI do
  @moduledoc """
  Functions for outputting text directly to the terminal, i.e. the opposite of the TUI.
  """

  import Historian.Gettext

  @txt_id_col_header "id"
  @txt_search_results_for "Search results for"
  @txt_value_col_header "value"

  # Looks like teal + cyan?
  @search_color_term_label IO.ANSI.color(1, 5, 3)

  @table_decoration_wrap "+"
  @table_decoration_separator_rows "-"
  @table_decoration_separator_cols "|"

  def search_results(term, results) do
    highlight_matching_lines(results, term)
    |> table()
  end

  def table(%Historian.History{items: lines}) do
    table(lines)
  end

  def table(lines) do
    id_col_header = gettext(@txt_id_col_header)
    value_col_header = gettext(@txt_value_col_header)
    value_header_length = String.length(value_col_header) + 1
    id_header_length = String.length(id_col_header)

    max_line_length = Enum.map(lines, &String.length(&1.value)) |> Enum.max()
    max_number_of_digits = Enum.count(lines) |> to_string() |> String.length()
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
    highlighted =
      [IO.ANSI.color(1, 5, 3), :bright, term, :reset]
      |> IO.ANSI.format_fragment()
      |> IO.iodata_to_binary()

    Enum.map(matching_items, &highlighted_term(&1, term, highlighted))

    matching_items
    |> Enum.map(fn item ->
      value = String.replace(item.value, term, highlighted)
      %{item | value: value}
    end)
  end

  defp highlighted_term(%{value: value} = item, term, highlighted) do
    %{item | value: String.replace(value, term, highlighted)}
  end

  defp table_row(padding, index, value, value_length, max_index_length, max_value_length) do
    index_string = to_string(index)
    index_digits = index_string |> String.length()

    extra_index_padding = col_padding(max_index_length, index_digits)
    extra_line_padding = col_padding(max_value_length, value_length)

    fill_table_row(padding, index_string, extra_index_padding, value, extra_line_padding)
  end
end
