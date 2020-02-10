defmodule Historian do
  @moduledoc """
  Documentation for `Historian`.
  """

  alias Historian.{Buffer, Config, History, Server}

  @last_read_key :last_read

  def print_lines(:last_result) do
    last_slice()
    |> Scribe.print()
  end

  def last_slice() do
    Buffer.first()
  end

  def search(matching) do
    {:ok, regexp} = Regex.compile(matching)
    results = last_slice() |> History.search(regexp) |> highlight_lines(matching)

    _ok = format_output(:search, results, "#{matching}")
  end

  def fetch(name, opts \\ [pretty_print: false]) do
    output = entry_server() |> do_read(name)
    lines = join_lines(output.items)
    output = if opts[:pretty_print], do: Code.format_string!(lines), else: lines

    _ok = format_output(:archive, output, "#{name}") |> IO.puts()
  end

  def archive(entry_name, action, action_opts \\ []) when action in [:pluck, :select] do
    history = last_slice()

    output =
      case action do
        :select -> History.slice(history, action_opts[:start], action_opts[:stop])
        :pluck -> History.pluck(history, action_opts)
      end

    archive_entry = %{
      output
      | name: entry_name,
        __meta__: %{created_at: DateTime.utc_now(), app_info: app_info()}
    }

    IO.ANSI.format([:bright, :yellow, "Stashed result of #{action} to #{entry_name}"])
    |> IO.puts()

    _ = entry_server() |> do_write(entry_name, archive_entry)

    :ok
  end

  def pluck(indexes) when is_list(indexes) do
    output = do_pluck(indexes) |> join_lines()
    _ok = format_output(output, indexes) |> IO.puts()

    {:ok, output}
  end

  def select(start, stop) do
    output = do_select(start, stop)
    lines = join_lines(output)
    _ok = format_output(lines, start..stop) |> IO.puts()
  end

  def eval_entry(entry_name) do
    output =
      entry_server()
      |> do_read(entry_name)

    Code.eval_string(output)
  end

  def entry_to_fun(entry_name) do
    output =
      entry_server()
      |> do_read(entry_name)

    fn ->
      Code.eval_string(output)
    end
  end

  def save_entries! do
    do_save()
  end

  def view_history(lines \\ 10, start \\ 0) do
    history_server() |> fetch_group_history(start, lines)

    Ratatouille.run(Historian.TerminalUI, quit_events: [key: Ratatouille.Constants.key(:ctrl_d)])
  end

  def slice!(lines \\ 10, start \\ 0) do
    history =
      history_server()
      |> fetch_group_history(start, lines)

    Scribe.print(history.items, data: [{"id", :id}, {"value", :value}])
  end

  defp do_select(start, stop) do
    Buffer.first()
    |> History.slice!(start, stop)
  end

  defp do_pluck(indexes) when is_list(indexes) do
    history_server()
    |> do_read(@last_read_key)
    |> History.pluck!(indexes)
  end

  defp join_lines(items) do
    items
    |> Enum.map(&Map.get(&1, :value))
    |> Enum.join("\n")
  end

  defp format_output(:search, output, name) do
    IO.ANSI.format([
      :yellow,
      :bright,
      "Search",
      " ",
      "results for: ",
      :cyan,
      name,
      :reset,
      "\n\n"
    ])
    |> IO.puts()

    Scribe.print(output, data: [{"id", :id}, {"value", :value}], colorize: false)
  end

  defp format_output(:archive, output, name) do
    IO.ANSI.format([
      :yellow,
      :bright,
      "Output",
      " ",
      "for archive ",
      :cyan,
      name,
      :yellow,
      ":",
      :reset,
      :bright,
      "\n\n",
      output,
      "\n\n"
    ])
  end

  defp format_output(output, indexes) do
    lines = inspect(indexes)

    IO.ANSI.format([
      :yellow,
      :bright,
      "Output",
      " ",
      "for lines ",
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
  end

  defp fetch_group_history(_server, start, lines) do
    history_slice =
      :group_history.load()
      |> Enum.slice(start + 1, lines)
      |> History.create()

    Buffer.push(history_slice)
  end

  defp do_read(server, key) do
    Server.read_value(server, key)
  end

  defp do_save() do
    entry_server() |> Server.save_table()
  end

  defp do_write(server, key, value) do
    Server.insert_value(server, key, value)
  end

  defp history_server do
    Config.history_server_name()
  end

  defp entry_server do
    Config.entry_server_name()
  end

  defp app_info do
    Application.started_applications() |> List.first()
  end

  defp highlight_lines(matching_items, term) do
    highlighted = IO.ANSI.format([IO.ANSI.color(1, 5, 3), :bright, term, :reset]) |> to_string()

    matching_items
    |> Enum.map(fn item ->
      value = String.replace(item.value, term, highlighted)
      %{item | value: value}
    end)
  end
end
