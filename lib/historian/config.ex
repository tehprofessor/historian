defmodule Historian.Config do
  def archive_table_name do
    Application.get_env(:historian, :archive_table_name)
  end

  def archive_filename do
    Application.get_env(:historian, :archive_filename)
  end

  def config_path do
    Application.get_env(:historian, :config_path, default_config_path())
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

  def archive_path do
    filename = archive_filename()
    archive_root = config_path()
    Path.join(archive_root, filename)
  end

  defp default_config_path do
    Path.join([System.user_home(), ".config", "historian"])
  end
end
