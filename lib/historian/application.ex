defmodule Historian.Application do
  @moduledoc false

  use Application

  alias Historian.Config

  @history_table :history_table
  @archive_table :historian_archive_db

  def start(_type, _args) do
    history_server_name = Config.history_server_name()
    first_screen = get_first_screen!()

    children = [
      # Create a process to interact with the current history
      server_spec(history_server_name, @history_table, nil, false),
      archive_spec(@archive_table),
      ui_server(first_screen),
      # Create a process for the history buffer
      buffer_spec()
    ]

    opts = [strategy: :one_for_one, name: Historian.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp get_first_screen! do
    if Config.persist_archive?() do
      archive_path = Config.archive_path()

      if File.exists?(archive_path) do
        Config.setup(:complete)
      end
    end

    Config.first_screen()
  end

  defp ui_server(screen) do
    %{
      id: Historian.UserInterfaceServer,
      start: {Historian.UserInterfaceServer, :start_link, [screen, []]}
    }
  end

  defp server_spec(server_name, table_name, file_path, persisted) do
    %{
      id: server_name,
      start:
        {Historian.Server, :start_link, [server_name, {table_name, file_path, persisted}, []]}
    }
  end

  defp archive_spec(table_name) do
    %{
      id: Historian.Archive,
      start: {Historian.Archive, :start_link, [table_name, []]}
    }
  end

  defp buffer_spec() do
    %{
      id: Historian.Buffer,
      start: {Historian.Buffer, :start_link, []}
    }
  end
end
