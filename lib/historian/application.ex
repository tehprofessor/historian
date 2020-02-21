defmodule Historian.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      archive_spec(),
      ui_server_spec(),
      # Create a process for the history buffer
      buffer_spec()
    ]

    opts = [strategy: :one_for_one, name: Historian.Supervisor]

    Supervisor.start_link(children, opts)
  end

  defp ui_server_spec() do
    %{
      id: Historian.UserInterface,
      start: {Historian.UserInterface, :start_link, []}
    }
  end

  defp archive_spec() do
    %{
      id: Historian.Archive,
      start: {Historian.Archive, :start_link, []},
      restart: :permanent,
      shutdown: :brutal_kill
    }
  end

  defp buffer_spec() do
    %{
      id: Historian.Buffer,
      start: {Historian.Buffer, :start_link, []}
    }
  end
end
