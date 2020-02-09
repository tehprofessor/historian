defmodule Historian.Server do
  use GenServer

  defstruct [:table, :persisted, :file_path]

  def start_link(id, {table_name, file_path, persist_table}, _opts \\ []) do
    GenServer.start_link(__MODULE__, {table_name, file_path, persist_table}, name: id)
  end

  def init({table_name, file_path, persist_table}) do
    table = initialize_table({table_name, file_path})
    instance = %__MODULE__{table: table, persisted: persist_table, file_path: file_path}
    # Note: We could handle continue here but it doesn't really do anything for us...
    {:ok, instance}
  end

  def insert_value(server, key, value) do
    _ = GenServer.cast(server, {:write, key, value})
    value
  end

  def view_table(server) do
    value = GenServer.call(server, :all)
    value
  end

  def read_value(server, key) do
    GenServer.call(server, {:read, key})
  end

  def save_table(server) do
    GenServer.call(server, :save)
  end

  # FIXME/TODO: This does not work like I thought it would
  def terminate(_reason, state) do
    _ = :ets.tab2file(state.table, '.historian-entries') |> IO.inspect(label: "historian entries persisted to file: .historian-entries")
  end

  def handle_cast({:write, key, value}, state) do
    _ = :ets.insert(state.table, {key, value})
    {:noreply, state}
  end

  def handle_call(:all, _from, state) do
    value = :ets.tab2list(state.table)
    {:reply, value, state}
  end

  def handle_call({:read, key}, _from, state) do
    [{^key, value}] = :ets.lookup(state.table, key)
    {:reply, value, state}
  end

  def handle_call(:save, _from, state) do
    _ = :ets.tab2file(state.table, state.filename)
    {:reply, :ok, state}
  end

  defp initialize_table({table_name, nil}) do
    :ets.new(table_name, [:public])
  end

  defp initialize_table({table_name, file_path}) do
    if File.exists?(file_path) do
      {:ok, table} = :ets.file2tab(to_charlist(file_path), verify: true)
      table
    else
      initialize_table({table_name, nil})
    end
  end
end
