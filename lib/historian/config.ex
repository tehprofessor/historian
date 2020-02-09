defmodule Historian.Config do

  def config_path do
    default = Path.join([System.user_home(), ".config", "historian"])
    Application.get_env(:historian, :config_path, default)
  end

  def archive_filename do
    Application.get_env(:historian, :archive_filename, "historian-db.ets")
  end

  def archive_path do
    filename = archive_filename()
    archive_path = config_path()
    Path.join(archive_path, filename)
  end

  def entry_server_name do
    Application.get_env(:historian, :entry_server_name, Historian.EntryServer)
  end

  def history_server_name do
    Application.get_env(:historian, :history_server_name, Historian.HistoryServer)
  end
end
