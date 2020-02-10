defmodule Historian.Archive do
  use GenServer

  alias Historian.Config

  defstruct [:config_path, :filename, :persisted, :table, :table_name]

  defmodule Item do
    defstruct name: nil, items: [], __meta__: %{}

    def new(name, items) do
      %__MODULE__{name: name, items: items, __meta__: meta()}
    end

    defp app_info do
      Enum.find(Application.started_applications(), fn {name, _, _} ->
        name == Mix.Project.config()[:app]
      end)
    end

    defp meta do
      %{created_at: DateTime.utc_now(), app_info: app_info()}
    end
  end

  def start_link(table_name, _opts \\ []) do
    GenServer.start_link(__MODULE__, table_name, name: __MODULE__)
  end

  def init(table_name) do
    instance = initialize_state(table_name)

    # Note: We could handle continue here but it doesn't really do anything for us...
    {:ok, instance}
  end

  def setup!() do
    config_path = Config.config_path()
    :ok = File.mkdir_p!(config_path)

    with {:ok, _} <- save!() do
      {:ok, :completed_setup}
    end
  rescue
    err in File.Error -> {:error, err}
  end

  def insert_value(key, value) do
    _ = GenServer.cast(__MODULE__, {:write, key, value})
    value
  end

  def delete_value(key) do
    GenServer.call(__MODULE__, {:delete, key})
  end

  def read_value(key) do
    GenServer.call(__MODULE__, {:read, key})
  end

  def update_value(%Item{} = updated_item, previous_item) do
    _ = GenServer.cast(__MODULE__, {:update, updated_item, previous_item})
    updated_item
  end

  def all() do
    GenServer.call(__MODULE__, :all)
  end

  def db_table() do
    GenServer.call(__MODULE__, :table_name)
  end

  def save!() do
    GenServer.call(__MODULE__, :save)
  end

  def reload!() do
    GenServer.call(__MODULE__, :reload)
  end

  def handle_call(:all, _from, state) do
    values = for {_key, value} <- :ets.tab2list(state.table), do: value
    {:reply, values, state}
  end

  def handle_call({:delete, key}, _from, state) do
    :ets.delete(state.table, key)

    {:reply, :ok, state}
  end

  def handle_call({:read, key}, _from, state) do
    item =
      case :ets.lookup(state.table, key) do
        [{^key, value}] -> value
        _ -> nil
      end

    {:reply, item, state}
  end

  def handle_call(:reload, _from, state) do
    new_state = initialize_state(state.table_name, state.table)

    {:reply, {:ok, new_state}, new_state}
  end

  def handle_call(:save, _from, state) do
    result = do_save!(state)

    {:reply, result, state}
  end

  def handle_call(:table_name, _from, state) do
    {:reply, state.table, state}
  end

  def handle_cast({:update, %{name: key} = updated_item, %{name: key}}, state) do
    _ = :ets.insert(state.table, {key, updated_item})
    _ = do_save!(state)

    {:noreply, state}
  end

  def handle_cast({:update, %{name: new_key} = updated_item, %{name: old_key}}, state) do
    _ = :ets.insert(state.table, {new_key, updated_item})
    _ = :ets.delete(state.table, old_key)
    _ = do_save!(state)

    {:noreply, state}
  end

  def handle_cast({:write, key, value}, state) do
    archive_item = Item.new(key, value)
    _ = :ets.insert(state.table, {key, archive_item})
    _ = do_save!(state)

    {:noreply, state}
  end

  defp initialize_state(table_name, table \\ nil) do
    config_path = Config.config_path()
    filename = Config.archive_filename()
    persisted = Config.persist_archive?()

    initialize_table!(%__MODULE__{
      table: table,
      table_name: table_name,
      persisted: persisted,
      config_path: config_path,
      filename: filename
    })
  end

  defp initialize_table!(
         %{
           table: nil,
           table_name: table_name,
           config_path: config_path,
           filename: filename,
           persisted: persisted
         } = instance
       ) do
    table =
      if Config.setup?() do
        initialize_table(table_name, persisted, config_path, filename)
      else
        initialize_table(table_name, false, config_path, filename)
      end

    %{instance | table: table}
  end

  defp initialize_table!(instance) do
    instance
  end

  defp initialize_table(_table_name, true = _from_disk, config_path, filename) do
    db_file = db_file_path(config_path, filename)
    {:ok, table} = :ets.file2tab(to_charlist(db_file), verify: true)
    table
  end

  defp initialize_table(table_name, _in_memory, _config_path, _filename) do
    :ets.new(table_name, [:public])
  end

  defp db_file_path(config_path, filename) do
    Path.join(config_path, filename)
  end

  defp do_save!(state) do
    do_save(state)
  end

  defp do_save(%{table: table, persisted: true, config_path: config_path, filename: filename}) do
    db_file = db_file_path(config_path, filename) |> to_charlist()

    with :ok <- :ets.tab2file(table, db_file) do
      {:ok, db_file}
    end
  end

  defp do_save(%{persisted: false}) do
    {:ok, ''}
  end
end
