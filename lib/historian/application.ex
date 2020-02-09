defmodule Historian.Application do
  @moduledoc false

  use Application

  alias Historian.Config

  @history_table :history_table
  @entry_table :entry_table
  @archive_table :historian_archive_db

  def start(_type, _args) do
    config_path = Config.config_path()
    archive_filename = Config.archive_filename()
    history_server_name = Config.history_server_name()
    entry_server_name = Config.entry_server_name()

    children = [
      # Create a process to interact with the current history
      server_spec(history_server_name, @history_table, nil, false),
      archive_spec(@archive_table, config_path, archive_filename, true),
      # Create a process for the history buffer
      buffer_spec(),
    ]

    opts = [strategy: :one_for_one, name: Historian.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp server_spec(server_name, table_name, file_path, persisted) do
    %{
      id: server_name,
      start: {Historian.Server, :start_link, [server_name, {table_name, file_path, persisted}, []]}
    }
  end

  defp archive_spec(table_name, config_path, archive_filename, persisted) do
    %{
      id: Historian.Archive,
      start: {Historian.Archive, :start_link, [{table_name, config_path, archive_filename, persisted}, []]}
    }
  end

  defp buffer_spec() do
    %{
      id: Historian.Buffer,
      start: {Historian.Buffer, :start_link, []}
    }
  end
end
