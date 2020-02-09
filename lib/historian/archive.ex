defmodule Historian.Archive do
  use GenServer

  defstruct [:config_path, :filename, :persisted, :table, :table_name]

  defmodule Item do
    defstruct [name: nil, items: [], __meta__: %{}]

    def new(name, items) do
      %__MODULE__{name: name, items: items, __meta__: meta()}
    end

    defp app_info do
      Application.started_applications() |> List.first()
    end

    defp meta do
      %{created_at: DateTime.utc_now(), app_info: app_info()}
    end
  end

  def start_link({table_name, config_path, filename, persisted}, _opts \\ []) do
    GenServer.start_link(__MODULE__, {table_name, config_path, filename, persisted},
      name: __MODULE__
    )
  end

  def init({table_name, config_path, filename, persisted}) do
    instance = initialize_table!(%__MODULE__{
      table_name: table_name,
      persisted: persisted,
      config_path: config_path,
      filename: filename
    })

    # Note: We could handle continue here but it doesn't really do anything for us...
    {:ok, instance}
  end

  def insert_value(key, value) do
    _ = GenServer.cast(__MODULE__, {:write, key, value})
    value
  end

  def update_value(%Item{} = updated_item, previous_item) do
    _ = GenServer.cast(__MODULE__, {:update, updated_item, previous_item})
    updated_item
  end

  def all() do
    GenServer.call(__MODULE__, :all)
  end

  def read_value(key) do
    GenServer.call(__MODULE__, {:read, key})
  end

  def save!() do
    GenServer.call(__MODULE__, :save)
  end

  def handle_cast({:write, key, value}, state) do
    archive_item = Item.new(key, value)
    _ = :ets.insert(state.table, {key, archive_item})
    _ = do_save(state)

    {:noreply, state}
  end

  def handle_cast({:update, %{name: key} = updated_item, %{name: key}}, state) do
    _ = :ets.insert(state.table, {key, updated_item})
    _ = do_save(state)

    {:noreply, state}
  end

  def handle_cast({:update, %{name: new_key} = updated_item, %{name: old_key}}, state) do
    _ = :ets.insert(state.table, {new_key, updated_item})
    _ = :ets.delete(state.table, old_key)
    _ = do_save(state)

    {:noreply, state}
  end

  def handle_call(:all, _from, state) do
    values = for {_key, value} <- :ets.tab2list(state.table), do: value
    {:reply, values, state}
  end

  def handle_call({:read, key}, _from, state) do
    [{^key, value}] = :ets.lookup(state.table, key)
    {:reply, value, state}
  end

  def handle_call(:save, _from, state) do
    result = do_save(state)

    {:reply, result, state}
  end

  defp initialize_table({table_name, nil}) do
    :ets.new(table_name, [:public])
  end

  defp initialize_table!(%{table_name: table_name, config_path: config_path, filename: filename} = instance) do
    db_file = db_file_path(config_path, filename)

    table =
      if File.exists?(db_file) do
        {:ok, table} = :ets.file2tab(to_charlist(db_file), verify: true)
        table
      else
        initialize_table({table_name, nil})
      end

    %{instance | table: table}
  end

  defp db_file_path(config_path, filename) do
    Path.join(config_path, filename)
  end

  defp do_save(state, opts \\ [silent: true])

  defp do_save(%{table: table, config_path: config_path, filename: filename}, silent: true) do
    db_file = db_file_path(config_path, filename) |> to_charlist()

    with :ok <- :ets.tab2file(table, db_file) do
      {:ok, db_file}
    end
  end

  defp do_save(state, silent: false) do
    with {:ok, db_file} <- do_save(state, silent: true) do
      IO.puts("historian persisted archive to: #{db_file}")

      {:ok, db_file}
    end
  end
end
