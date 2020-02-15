defmodule Historian.ArchiveTest do
  use ExUnit.Case

  alias Historian.Archive

  require Logger

  @moduletag capture_log: true

  setup do
    table_name = :historian_testing_db
    _ = Application.put_env(:historian, :archive_table_name, table_name)

    {:ok, %{filename: Historian.Config.archive_filename(), config_path: Historian.Config.config_path()}}
  end

  describe "Archive.Item" do
    test "new/0" do
      current_version = Mix.Project.config()[:version] |> to_charlist()
      item = Archive.Item.new(:womp_womp, ":boring")

      assert %Archive.Item{
               __meta__: %{app_info: {:historian, 'historian', ^current_version}, created_at: _},
               items: ":boring",
               name: :womp_womp
             } = item
    end
  end

  test "db_table/0" do
    {:ok, archive} = GenServer.start_link(Archive, :ok)
    assert Archive.db_table(archive)
  end

  test "delete_value/1" do
    {:ok, archive} = GenServer.start_link(Archive, :ok)
    _ = Archive.insert_value(archive, :yolo, "IO.puts()")

    assert :ok = Archive.delete_value(archive, :yolo)
    assert Archive.read_value(archive, :yolo) == nil
  end

  test "save!/0", %{config_path: config_path, filename: filename}do
    old_table_name = Application.get_env(:historian, :archive_table_name)
    _ = Application.put_env(:historian, :archive_table_name, :historian_save_test)

    {:ok, archive} = GenServer.start_link(Archive, :ok)

    _ = Archive.setup!(archive)

    expected_names = [:poodle, :stroodle]
    Enum.each(expected_names, &Archive.insert_value(archive, &1, "IO.puts(#{&1})"))

    _ = Archive.save!(archive)

    table_name = Application.get_env(:historian, :archive_table_name)
    # The table is named, and named tables cannot be loaded from disk, if a table with that name already exists in :ets.
    # Thus, before reloading it from disk, we must remove it
    _ = :ets.rename(table_name, :historian_save_test_old)

    db_file = Path.join(config_path, filename)

    assert {:ok, table} = :ets.file2tab(to_charlist(db_file), verify: true)

    Enum.each(expected_names, fn name ->
      assert [{^name, %Archive.Item{name: ^name}}] = :ets.lookup(table, name)
    end)

    # Cleanup the testing database file.
    ensure_dont_be_an_asshole!(config_path, filename)

    _ = Application.put_env(:historian, :archive_table_name, old_table_name)
  end

  test "save/0 - persistence off" do
    old_filename = Application.get_env(:historian, :archive_filename)
    not_persisted_filename = ".historian-db-test-do-not-persist.ets"
    _ = Application.put_env(:historian, :persist_archive, false)
    _ = Application.put_env(:historian, :archive_filename, not_persisted_filename)

    {:ok, archive} = GenServer.start_link(Archive, :ok)
#    _ = Archive.reload!()
#    _ = wait_for_archive!()
#
    failed_persistence_off_message =
      "Failed! Saving Archive without persistence returned unexpected result."

    assert {:ok, ''} = Archive.save!(archive), failed_persistence_off_message

    failed_to_not_persist_message =
      "Failed! Archive persisted to disk when persistence is turned off."

    assert File.exists?(Historian.Config.archive_filename()) == false,
           failed_to_not_persist_message

    _ = Application.put_env(:historian, :persist_archive, nil)
    _ = Application.put_env(:historian, :archive_filename, old_filename)
  end


  test "setup/0", %{config_path: config_path, filename: filename} do
    {:ok, archive} = GenServer.start_link(Archive, :ok)

    assert Archive.configured?(archive) == false, "Failed setup test, archive is already configured. Please make sure tests are being properly cleaned up after."
    assert Archive.setup!(archive) == {:ok, :setup_completed}
    assert Archive.configured?(archive), "Error! Setup failed to configure the archive but returned {:ok, :setup_completed}"

    # Cleanup the testing database file.
    ensure_dont_be_an_asshole!(config_path, filename)
  end

  test "insert_value/2" do
    expected = "IO.puts()"
    current_version = Mix.Project.config()[:version] |> to_charlist()
    {:ok, archive} = GenServer.start_link(Archive, :ok)

    assert Archive.insert_value(archive, :yolo, "IO.puts()") == expected
    table = Archive.db_table(archive)

    assert [
             yolo: %Archive.Item{
               __meta__: %{app_info: {:historian, 'historian', ^current_version}, created_at: _},
               items: "IO.puts()",
               name: :yolo
             }
           ] = :ets.lookup(table, :yolo)
  end

  test "read_value/1" do
    current_version = Mix.Project.config()[:version] |> to_charlist()
    {:ok, archive} = GenServer.start_link(Archive, :ok)
    _ = Archive.insert_value(archive, :yolo, "IO.puts()")

    assert %Archive.Item{
             __meta__: %{app_info: {:historian, 'historian', ^current_version}, created_at: _},
             items: "IO.puts()",
             name: :yolo
           } = Archive.read_value(archive, :yolo)

    # Reading a non-existent key returns nil
    assert Archive.read_value(archive, :does_not_exist) == nil
  end

  test "update_value/2" do
    {:ok, archive} = GenServer.start_link(Archive, :ok)
    _ = Archive.insert_value(archive, :yolo, "IO.puts()")
    item = Archive.read_value(archive, :yolo)
    updated_item = %{item | name: :egalitarianism}

    assert Archive.update_value(archive, updated_item, item) == updated_item
    # Read the value back with the new name
    assert Archive.read_value(archive, :egalitarianism) == updated_item
    # Make sure the old value has been removed
    assert Archive.read_value(archive, :yolo) == nil
  end

  test "all/0" do
    {:ok, archive} = GenServer.start_link(Archive, :ok)
    expected_names = [:poodle, :stroodle]
    Enum.each(expected_names, &Archive.insert_value(archive, &1, "IO.puts(#{&1})"))

    results = Archive.all(archive)
    assert Enum.count(results) == 2, "Incorrect number of results\n\texpected: #{inspect(expected_names)}\n\tfound: #{inspect(Enum.map(results, &(&1.name)))}"

    Enum.each(results, fn %{name: name} ->
      assert Enum.member?(expected_names, name),
             "Error! %Item{name: #{name}} not found in expected list #{inspect(expected_names)}"
    end)
  end

  defp ensure_dont_be_an_asshole!(__DIR__, filename) do
    assert File.rm!(Path.join(__DIR__, filename))
  end

  defp ensure_dont_be_an_asshole!(config_path, "historian-db.ets" = filename) do
    fail_asshole!(config_path, filename)
  end

  defp fail_asshole!(config_path, filename) do
    flunk("""
    ASSHOLE MOVE DETECTED!

    Tried to deleted the user's historian db file, because you're an asshole an did not configure things correctly.

    config_path: #{config_path}
    filename: #{filename}
    """)
  end
end
