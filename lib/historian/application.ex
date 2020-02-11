defmodule Historian.Application do
  @moduledoc false

  use Application

  alias Historian.Config

  @archive_table :historian_archive_db

  def start(_type, _args) do
    first_screen = get_first_screen!()

    children = [
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
