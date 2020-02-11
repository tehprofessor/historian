defmodule Historian do
  @moduledoc """
  Documentation for `Historian`.
  """

  alias Historian.{Archive, Buffer, History}

  import Historian.Gettext

  @txt_id_col_header "id"
  @txt_no_entry_for "No entry for"
  @txt_output_for_archive "Output for archive"
  @txt_output_for_lines "Output for lines"
  @txt_search_results_for "Search results for"
  @txt_value_col_header "value"

  @doc """
  Create an archive entry with the given name and value.

  ## Parameters

    - entry_name: Name of the new entry
    - entry_value: Value (i.e. content) of the new entry
  """
  @spec archive_entry!(atom(), String.t()) :: String.t()
  def archive_entry!(entry_name, entry_value) do
    Archive.insert_value(entry_name, entry_value)
  end

  @doc """
  Create an archive entry with the given name using the contents of your clipboard.

  ## Parameters

    - entry_name: Name of the entry to eval.
  """
  @spec archive_from_clipboard!(atom()) :: String.t() | {:error, any()}
  def archive_from_clipboard!(entry_name) do
    with {:ok, data} <- Historian.Clipboard.paste() do
      archive_entry!(entry_name, String.trim(data))
    end
  end

  @doc """
  Create an archive entry from the current history buffer, extracting it with given action and action opts.

  ## Parameters

    - entry_name: Name of the entry to eval.
    - action: Action to use for extracting the value from the history buffer, either `slice/3` or `pluck/2`.
    - action_opts: List of arguments for the given action, see an action's documentation for required args.
  """
  @spec archive_from_history!(atom(), :pluck | :slice, list(any())) :: String.t()
  def archive_from_history!(entry_name, action, action_opts \\ [])
      when action in [:pluck, :select] do
    history = current_buffer()

    item =
      case action do
        :select ->
          [start, stop] = action_opts
          History.slice(history, start, stop)

        :pluck ->
          History.pluck(history, action_opts)
      end

    archive_entry!(entry_name, item.value)
  end

  @doc """
  Copy the entry's contents to your clipboard, returns `{:ok, data}` if was copied to your clipboard successfully
  or `{:error, reason}` if there was a problem.

  ## Parameters

    - entry_name: Name of the entry to copy.

  ## Usage over SSH

  If you want to use Historian on a remote system, you'll need to properly configure SSH or coping lines _will fail_.
  Eventually, there will be a guide on how to use Historian with SSH.
  """
  @spec copy(atom()) :: Historian.Clipboard.copy_result()
  def copy(entry_name) do
    item = Archive.read_value(entry_name)
    lines = join_lines(item.items)

    Historian.Clipboard.copy(lines)
  end

  @doc """
  Evaluate the entry and return the result; uses `Code.eval_string/1` to obtain the result.

  ## Parameters

    - entry_name: Name of the entry to eval.
  """
  @spec eval_entry(atom()) :: any()
  def eval_entry(entry_name) do
    Archive.read_value(entry_name) |> join_lines() |> Code.eval_string()
  end

  @doc """
  Turn the entry into a zero-arity function; uses `Code.eval_string/1` to call the given lines within the function.

  ## Parameters

    - entry_name: Name of the entry to turn into a function.
  """
  @spec entry_to_fun(atom()) :: (() -> any())
  def entry_to_fun(entry_name) do
    code_snippet = Archive.read_value(entry_name) |> join_lines()

    fn ->
      Code.eval_string(code_snippet)
    end
  end

  def current_buffer() do
    Buffer.first()
  end

  @spec pluck(list(pos_integer())) :: {:ok, String.t()}
  def pluck(indexes) when is_list(indexes) do
    output = do_pluck(indexes) |> join_lines()
    {:ok, output}
  end

  @spec print_pluck(list(pos_integer())) :: :ok
  def print_pluck(indexes) when is_list(indexes) do
    {:ok, output} = pluck(indexes)
    format_output(output, indexes, colorize: true) |> IO.puts()
  end

  def print_lines(:last_result) do
    current_buffer()
    |> Scribe.print()
  end

  @doc """
  Search the current history buffer for lines matching the term and print them to screen.
  """
  @spec search(String.t()) :: :ok
  def search(matching) do
    {:ok, regexp} = Regex.compile(matching)
    results = current_buffer() |> History.search(regexp) |> highlight_lines(matching)

    _ok = format_output(:search, results, "#{matching}", colorize: true)
  end

  @doc """
  Select the given lines (from the last history buffer) and print them to screen.

  ## Parameters

    - start: Line number to start selecting lines at
    - stop: Line number to stop selecting lines at
  """
  @spec select(non_neg_integer(), non_neg_integer()) :: :ok
  def select(start, stop) do
    output = do_select(start, stop)
    lines = join_lines(output)
    format_output(lines, start..stop, colorize: true) |> IO.puts()
  end

  @doc """
  Print the contents of the matching archive entry _or_ a message saying there is no matching entry.

  ## Parameters

    - entry_name: Name of the entry to view.
    - opts: `pretty_print: false` is the default, setting to `true` will output using `Code.format_string!/1`
  """
  @spec view_entry(atom, Keyword.t()) :: :ok
  def view_entry(name, opts \\ [pretty_print: false]) do
    output =
      case Archive.read_value(name) do
        nil ->
          gettext(@txt_no_entry_for) <> " #{inspect(name)}"

        item ->
          lines = join_lines(item.items)
          output = if opts[:pretty_print], do: Code.format_string!(lines), else: lines

          format_output(:archive, output, "#{name}", colorize: true)
      end

    IO.puts(output)
  end

  @doc """
  Starts an interactive Historian session.

  ## Parameters

    - lines: Number of lines of history to load into the buffer Historian UI.
    - start: Offset for number of lines.
  """
  @spec view_history(non_neg_integer(), non_neg_integer()) :: :ok
  def view_history(lines \\ 50, start \\ 0) do
    fetch_group_history(start, lines)

    Ratatouille.run(Historian.TerminalUI, quit_events: [key: Ratatouille.Constants.key(:ctrl_d)])
  end

  defp do_select(start, stop) do
    Buffer.first()
    |> History.slice!(start, stop)
  end

  defp do_pluck(indexes) when is_list(indexes) do
    Buffer.first()
    |> History.pluck!(indexes)
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

  # FIXME: These are not properly named and some are printing IO
  defp format_output(:search, output, name, colorize: false) do
    search_text = gettext(@txt_search_results_for) <> " #{name}:"
    IO.puts(search_text)

    print_table(:history, output)
  end

  defp format_output(:search, output, name, colorize: true) do
    search_text = gettext(@txt_search_results_for) <> " "

    IO.ANSI.format([
      :yellow,
      :bright,
      search_text,
      :cyan,
      name,
      :reset,
      "\n\n"
    ])
    |> IO.puts()

    print_table(:history, output)
  end

  defp format_output(:archive, output, name, colorize: false) do
    archive_text = gettext(@txt_output_for_archive) <> " #{name}:"
    IO.puts(archive_text <> "\n" <> output)
  end

  defp format_output(:archive, output, name, colorize: true) do
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
    ])
  end

  defp format_output(output, indexes, colorize: false) do
    lines = inspect(indexes)
    gettext(@txt_output_for_lines) <> " #{lines}:" <> "\n----\n" <> output <> "\n----\n"
  end

  defp format_output(output, indexes, colorize: true) do
    label_text = gettext(@txt_output_for_lines) <> " "
    lines = inspect(indexes)

    IO.ANSI.format([
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
    |> to_string()
  end

  defp fetch_group_history(start, lines) do
    history_slice =
      :group_history.load()
      |> Enum.slice(start + 1, lines)
      |> History.create()

    Buffer.push(history_slice)
  end

  defp highlight_lines(matching_items, term) do
    highlighted =
      IO.ANSI.format_fragment([IO.ANSI.color(1, 5, 3), :bright, term, :reset]) |> to_string()

    matching_items
    |> Enum.map(fn item ->
      value = String.replace(item.value, term, highlighted)
      %{item | value: value}
    end)
  end

  defp col_padding(maximum, amount) do
    String.duplicate(" ", max(maximum - amount, 0))
  end

  defp print_table(:history, []) do
    IO.puts("[empty table]\n")
  end

  defp print_table(:history, lines) do
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

    horizontal_separator = ["+", String.duplicate("-", horizontal_separator_length), "+", "\n"]

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
    |> IO.puts()
  end

  defp table_row(padding, index, value, value_length, max_index_length, max_value_length) do
    index_string = to_string(index)
    index_digits = index_string |> String.length()

    extra_index_padding = col_padding(max_index_length, index_digits)
    extra_line_padding = col_padding(max_value_length, value_length)

    do_table_row(padding, index_string, extra_index_padding, value, extra_line_padding)
  end

  defp do_table_row(padding, id, extra_index_padding, value, extra_value_padding) do
    [
      "|",
      padding,
      extra_index_padding,
      id,
      padding,
      "|",
      padding,
      value,
      extra_value_padding,
      padding,
      "|",
      "\n"
    ]
  end
end
