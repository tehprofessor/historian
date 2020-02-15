defmodule Historian do
  @moduledoc """
  Documentation for `Historian`.
  """

  alias Historian.{Archive, Buffer, History, PageBuffer}

  import Historian.Gettext

  @txt_no_entry_for "No entry for"
  @txt_output_for_archive "Output for archive"

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
    history = current_history()

    items =
      case action do
        :select ->
          [start, stop] = action_opts
          History.slice(history, start, stop)

        :pluck ->
          History.pluck(history, action_opts)
      end

    value = Enum.map(items, & &1.value) |> Enum.join("\n")
    archive_entry!(entry_name, value)
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

  defp page_history(pager) do
    {:ok, history} = PageBuffer.current(pager)
    history
  end

  def current_history() do
    pager = current_pager()
    {:ok, history} = PageBuffer.current(pager)
    history
  end

  def line(line_number) do
    case current_pager() |> PageBuffer.get_line(line_number) do
      %{value: value} -> to_string(value)
      _ ->
        _ = gettext("Invalid line number") |> IO.puts()
        nil
    end
  end

  @spec next_page(pager :: pid()) :: pid()
  def next_page(pager) do
    with {:ok, %{items: items}} <- PageBuffer.next(pager),
         %{page: current_page} <- PageBuffer.info(pager) do
      output_title = " " <> to_string(current_page)

      Historian.TextUI.page(items, [output_title], true)
      |> IO.puts()
    else
      _ -> IO.puts("Page is out of bounds")
    end

    pager
  end

  @spec pages(page_size :: pos_integer()) :: pid()
  def pages(page_size \\ 100) do
    pager = new_page_buffer(page_size)

    _ = page(pager, 0)

    pager
  end

  @spec page(pager :: pid(), page :: pos_integer()) :: {:ok, String.t()}
  def page(pager, page_number) do
    with {:ok, %{items: items}} <- PageBuffer.get(pager, page_number) do
      output_title = " " <> to_string(page_number)

      Historian.TextUI.page(items, [output_title], true)
      |> IO.puts()
    else
      _ -> IO.puts("Page is out of bounds")
    end

    pager
  end

  @doc """
  Print the page and update the process's current page to be the provided page number.
  """
  @spec page!(pager :: pid(), page :: pos_integer()) :: {:ok, String.t()}
  def page!(pager, page_number) do
    with {:ok, %{items: items}} <- PageBuffer.set_page(pager, page_number) do
      output_title = " " <> to_string(page_number)

      Historian.TextUI.page(items, [output_title], true)
      |> IO.puts()
    else
      _ -> IO.puts("Page is out of bounds")
    end

    pager
  end

  @spec pluck(list(pos_integer())) :: {:ok, String.t()}
  def pluck(indexes) when is_list(indexes) do
    output = do_pluck(indexes) |> join_lines()
    {:ok, output}
  end

  @spec prev_page(pager :: pid()) :: pid()
  def prev_page(pager) do
    with {:ok, %{items: items}} <- PageBuffer.prev(pager),
         %{page: current_page} <- PageBuffer.info(pager) do
      output_title = " " <> to_string(current_page)

      Historian.TextUI.page(items, [output_title], true)
      |> IO.puts()
    else
      _ -> IO.puts("Page is out of bounds")
    end

    pager
  end

  @spec print_archive() :: :ok
  def print_archive() do
    archive = Archive.all()
    Historian.TextUI.page(archive, ["(ARCHIVE)"], true)
    |> IO.puts()
  end

  @spec print_pluck(list(pos_integer())) :: :ok
  def print_pluck(indexes) when is_list(indexes) do
    {:ok, output} = pluck(indexes)

    Historian.TextUI.lines(output, indexes, true)
    |> IO.puts()
  end

  @doc """
  Search the current history buffer for lines matching the term and print them to screen.
  """
  @spec search(String.t()) :: :ok
  def search(matching) do
    current_pager() |> search(matching)
  end

  @doc """
  Search the current history buffer for lines matching the term and print them to screen.
  """
  @spec search(page_buffer_pid :: pid(), String.t()) :: :ok
  def search(pager, matching) do
    {:ok, regexp} = Regex.compile(matching)

    page_history(pager)
    |> History.search!(regexp)
    |> Historian.TextUI.search_results(matching)
    |> IO.puts()
  end

  @doc """
  Select the given lines (from the last history buffer) and print them to screen.

  ## Parameters

    - start: Line number to start selecting lines at
    - stop: Line number to stop selecting lines at
  """
  @spec select(non_neg_integer(), non_neg_integer()) :: :ok
  def select(start, stop) do
    output = do_select(start, stop) |> join_lines()

    Historian.TextUI.lines(output, ["#{start}..#{stop}"], true)
    |> IO.puts()
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
  An alias of `tui!/0`.
  """
  def view_page() do
    tui!()
  end

  @doc """
  Starts an interactive Historian session using the provided page buffer process. If no page number is provided the
  current page from the given page buffer process will be used.

  ## Parameters

    - pager: The pid for a `Historian.PageBuffer` process.
    - page: The page to show in the Terminal UI
  """
  @spec view_page(pager :: pid(), non_neg_integer() | nil) :: pid()
  def view_page(pager, page_number \\ nil)

  def view_page(pager, nil) do
    tui!(pager)
  end

  def view_page(pager, page_number) do
    _ = PageBuffer.set_page(pager, page_number)
    tui!(pager)
  end

  def tui!(pager \\ nil)

  def tui!(nil) do
    current_pager() |> tui!()
  end

  def tui!(pager) when is_pid(pager) do
    with {:ok, _ref} <- Historian.UserInterfaceServer.set(pager) do
      _ = Ratatouille.run(Historian.TerminalUI, quit_events: [key: Ratatouille.Constants.key(:ctrl_d)])
    end
  end

  @doc """
  Starts an interactive Historian session.

  ## Parameters

    - lines: Number of lines of history to load into the buffer Historian UI.
    - start: Offset for number of lines.
  """
  @spec view_history(non_neg_integer(), non_neg_integer()) :: :ok
  def view_history(lines \\ 100, page \\ 0) do
    pager = new_page_buffer(lines)
    _ = PageBuffer.set_page(pager, page)

    tui!(pager)
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

  defp format_output(:archive, output, name, colorize: false) do
    archive_text = gettext(@txt_output_for_archive) <> " #{name}:"
    archive_text <> "\n" <> output
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

  defp current_pager() do
    case Buffer.first() do
      pager when is_pid(pager) ->
        if Process.alive?(pager),
           do: pager,
           else: new_page_buffer(100)
      nil -> new_page_buffer(100)
    end
  end

  defp new_page_buffer(page_size) do
    {:ok, pager} = PageBuffer.start_link(page_size)
    _ = Buffer.push(pager)

    pager
  end
end
