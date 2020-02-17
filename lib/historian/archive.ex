defmodule Historian.Archive do
  @moduledoc """
  A process responsible for managing the user's archive.

  ## Details

  The archive's database is an `ets` table, the persistence feature uses `:ets.tab2file/2` to write the table to disk,
  enabling the archive's visibility across applications.
  """
  use GenServer

  alias Historian.Config

  require Logger

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

  def setup!(server \\ __MODULE__) do
    config_path = Config.config_path()
    :ok = File.mkdir_p!(config_path)

    with {:ok, _} <- setup(server) do
      {:ok, :setup_completed}
    end
  rescue
    err in File.Error -> {:error, err}
  end

  def configured?(server \\ __MODULE__) do
    GenServer.call(server, :configured?)
  end

  def insert_value(server \\ __MODULE__, key, value) do
    _ = GenServer.call(server, {:write, key, value})
    value
  end

  def delete_value(server \\ __MODULE__, key) do
    GenServer.call(server, {:delete, key})
  end

  def read_value(server \\ __MODULE__, key) do
    GenServer.call(server, {:read, key})
  end

  def update_value(server \\ __MODULE__, %Item{} = updated_item, previous_item) do
    _ = GenServer.call(server, {:update, updated_item, previous_item})
    updated_item
  end

  def all(server \\ __MODULE__) do
    GenServer.call(server, :all)
  end

  def db_table(server \\ __MODULE__) do
    GenServer.call(server, :table_name)
  end

  def save!(server \\ __MODULE__) do
    GenServer.call(server, :save)
  end

  def dump(server \\ __MODULE__) do
    GenServer.call(server, :dump)
  end

  # - GenServer

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    instance = initialize_state()
    _ = Process.flag(:trap_exit, true)

    # Note: We could handle continue here but it doesn't really do anything for us...
    {:ok, instance}
  end

  def handle_call(:all, _from, state) do
    values = for {_key, value} <- :ets.tab2list(state.table_name), do: value
    {:reply, values, state}
  end

  def handle_call(:configured?, _from, state) do
    {:reply, is_configured?(state), state}
  end

  def handle_call({:delete, key}, _from, state) do
    :ets.delete(state.table_name, key)

    {:reply, :ok, state}
  end

  def handle_call({:read, key}, _from, state) do
    item =
      case :ets.lookup(state.table_name, key) do
        [{^key, value}] -> value
        _ -> nil
      end

    {:reply, item, state}
  end

  def handle_call(:dump, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:reload, _from, state) do
    {:stop, :normal, state, nil}
  end

  def handle_call(:setup, _from, state) do
    result = persist_table(state)

    {:reply, result, state}
  end

  def handle_call(:save, _from, state) do
    result = do_save!(state)

    {:reply, result, state}
  end

  def handle_call({:write, key, value}, _from, state) do
    archive_item = Item.new(key, value)
    _ = :ets.insert(state.table_name, {key, archive_item})
    _ = do_save!(state)

    {:reply, :ok, state}
  end

  def handle_call(:table_name, _from, state) do
    {:reply, state.table_name, state}
  end

  def handle_call({:update, %{name: key} = updated_item, %{name: key}}, _from, state) do
    _ = :ets.insert(state.table_name, {key, updated_item})
    _ = do_save!(state)

      {:reply, :ok, state}
  end

  def handle_call({:update, %{name: new_key} = updated_item, %{name: old_key}}, _from, state) do
    _ = :ets.insert(state.table_name, {new_key, updated_item})
    _ = :ets.delete(state.table_name, old_key)
    _ = do_save!(state)

    {:reply, :ok, state}
  end

  # - Private

  # persisted is only false _iff_ configured by the user, the default is nil or true.
  defp is_configured?(%{persisted: false}) do
    true
  end

  defp is_configured?(%{config_path: config_path, filename: filename, persisted: persisted?}) do
    existing_archive? = db_file_path(config_path, filename) |> File.exists?()
    existing_archive? && persisted?
  end

  defp initialize_state(table \\ nil) do
    table_name = Config.archive_table_name()
    config_path = Config.config_path()
    filename = Config.archive_filename()
    persisted = Config.persist_archive?()
    from_disk? = Config.archive_path() |> File.exists?()

    initialize_table!(from_disk?, %__MODULE__{
      table: table,
      table_name: table_name,
      persisted: persisted,
      config_path: config_path,
      filename: filename
    })
  end

  defp initialize_table!(
         _ = _from_disk?,
         %{
           table: nil,
           table_name: table_name,
           persisted: false
         } = instance
       ) do
    table = new_table(table_name)
    %{instance | table: table}
  end

  defp initialize_table!(
         true = _from_disk?,
         %{
           table: nil,
           config_path: config_path,
           filename: filename,
           persisted: true
         } = instance
       ) do
    table = new_table_from_disk(config_path, filename)
    %{instance | table: table}
  end

  defp initialize_table!(
         false = _from_disk?,
         %{
           table: nil,
           table_name: table_name,
           persisted: true
         } = instance
       ) do
    table = new_table(table_name)
    %{instance | table: table}
  end

  defp new_table_from_disk(config_path, filename) do
    db_file = db_file_path(config_path, filename)
    {:ok, table} = :ets.file2tab(to_charlist(db_file), verify: true)
    log_development_only(fn -> "Loaded table<#{table}> from disk: #{db_file}" end)
    table
  end

  defp new_table(table_name) do
    log_development_only(fn -> "create new table<#{table_name}> in memory" end)
    :ets.new(table_name, [:named_table, :public])
  end

  defp db_file_path(config_path, filename) do
    Path.join(config_path, filename)
  end

  defp do_save!(state) do
    if is_configured?(state) do
      persist_table(state)
    else
      persist_table(%{persisted: false})
    end
  end

  defp persist_table(%{table_name: table_name, persisted: true, config_path: config_path, filename: filename}) do
    db_file = db_file_path(config_path, filename) |> to_charlist()

    log_development_only(fn -> "saving archive<#{table_name}> to disk, at: #{db_file}" end)

    with :ok <- :ets.tab2file(table_name, db_file) do
      {:ok, db_file}
    end
  end

  defp persist_table(%{persisted: false}) do
    {:ok, ''}
  end

  defp setup(server) do
    _ = GenServer.call(server, :setup)
  end

  defp log_development_only(message) do
    project_config = Mix.Project.config()

    if project_config && project_config[:app] == :historian do
      Logger.debug(message)
    end
  end
end
