defmodule Historian.Config do
  def config_path do
    default = Path.join([System.user_home(), ".config", "historian"])
    Application.get_env(:historian, :config_path, default)
  end

  def archive_filename do
    Application.get_env(:historian, :archive_filename, "historian-db.ets")
  end

  def first_screen do
    case {persist_archive?(), setup?()} do
      {true, false} -> :welcome
      _ -> :view_history
    end
  end

  def persist_archive? do
    case Application.get_env(:historian, :persist_archive, true) do
      nil ->
        Application.put_env(:historian, :persist_archive, true)
        true

      other ->
        other
    end
  end

  def setup? do
    setup() == :complete
  end

  def setup(value \\ nil)

  def setup(nil) do
    Application.get_env(:historian, :setup, :missing)
  end

  def setup(value) do
    Application.put_env(:historian, :setup, value)
    value
  end

  def archive_path do
    filename = archive_filename()
    archive_root = config_path()
    Path.join(archive_root, filename)
  end

  def entry_server_name do
    Application.get_env(:historian, :entry_server_name, Historian.EntryServer)
  end

  def history_server_name do
    Application.get_env(:historian, :history_server_name, Historian.HistoryServer)
  end
end
