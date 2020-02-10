defmodule Historian.ArchiveTest do
  use ExUnit.Case

  alias Historian.Archive

  setup do
    old_env = capture_env([:config_path, :archive_filename, :persist_archive, :setup])

    on_exit(fn ->
      table = Archive.db_table()
      :ets.delete_all_objects(table)
      old_env.()
    end)
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

  test "setup/0" do
    config_path = __DIR__
    filename = ".historian-db-test.ets"
    _ = Application.put_env(:historian, :archive_filename, filename)
    _ = Application.put_env(:historian, :config_path, config_path)
    _ = Application.put_env(:historian, :setup, :complete)

    _ = Archive.reload!()
    assert {:ok, :completed_setup} = Archive.setup!()

    # Cleanup the testing database file.
    assert File.rm!(Path.join(config_path, filename))
  end

  test "db_table/0" do
    assert Archive.db_table()
  end

  test "delete_value/1" do
    _ = Archive.insert_value(:yolo, "IO.puts()")

    assert :ok = Archive.delete_value(:yolo)
    assert Archive.read_value(:yolo) == nil
  end

  test "insert_value/2" do
    expected = "IO.puts()"
    current_version = Mix.Project.config()[:version] |> to_charlist()

    assert Archive.insert_value(:yolo, "IO.puts()") == expected
    table = Archive.db_table()

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
    _ = Archive.insert_value(:yolo, "IO.puts()")

    assert %Archive.Item{
             __meta__: %{app_info: {:historian, 'historian', ^current_version}, created_at: _},
             items: "IO.puts()",
             name: :yolo
           } = Archive.read_value(:yolo)

    # Reading a non-existent key returns nil
    assert Archive.read_value(:does_not_exist) == nil
  end

  test "update_value/2" do
    _ = Archive.insert_value(:yolo, "IO.puts()")
    item = Archive.read_value(:yolo)
    updated_item = %{item | name: :egalitarianism}

    assert Archive.update_value(updated_item, item) == updated_item
    # Read the value back with the new name
    assert Archive.read_value(:egalitarianism) == updated_item
    # Make sure the old value has been removed
    assert Archive.read_value(:yolo) == nil
  end

  test "reload!/0" do
    _ = Application.put_env(:historian, :archive_filename, "historian-db-test.ets")
    _ = Application.put_env(:historian, :config_path, __DIR__)

    assert {:ok, %{filename: "historian-db-test.ets", config_path: __DIR__}} = Archive.reload!()
  end

  test "save!/0" do
    config_path = __DIR__
    filename = ".historian-db-test.ets"
    _ = Application.put_env(:historian, :archive_filename, filename)
    _ = Application.put_env(:historian, :config_path, config_path)
    _ = Application.put_env(:historian, :setup, :complete)

    {:ok, _new_state} = Archive.reload!()

    expected_names = [:poodle, :stroodle]
    Enum.each(expected_names, &Archive.insert_value(&1, "IO.puts(#{&1})"))

    _ = Archive.save!()
    db_file = Path.join(config_path, filename)

    assert {:ok, table} = :ets.file2tab(to_charlist(db_file), verify: true)

    Enum.each(expected_names, fn name ->
      assert [{^name, %Archive.Item{name: ^name}}] = :ets.lookup(table, name)
    end)

    # Cleanup the testing database file.
    assert File.rm!(Path.join(config_path, filename))

    # Check to make sure with persistence off works correctly
    _ = Application.put_env(:historian, :persist_archive, false)
    not_persisted_filename = ".historian-db-test-do-not-persist.ets"
    _ = Application.put_env(:historian, :archive_filename, not_persisted_filename)

    {:ok, _new_state} = Archive.reload!()

    failed_persistence_off_message =
      "Failed! Saving Archive without persistence returned unexpected result."

    assert {:ok, ''} = Archive.save!(), failed_persistence_off_message

    failed_to_not_persist_message =
      "Failed! Archive persisted to disk when persistence is turned off."

    assert File.exists?(Historian.Config.archive_filename()) == false,
           failed_to_not_persist_message
  end

  test "all/0" do
    expected_names = [:poodle, :stroodle]
    Enum.each(expected_names, &Archive.insert_value(&1, "IO.puts(#{&1})"))

    results = Archive.all()
    assert Enum.count(results) == 2

    Enum.each(results, fn %{name: name} ->
      assert Enum.member?(expected_names, name),
             "Error! %Item{name: #{name}} not found in expected list #{inspect(expected_names)}"
    end)
  end

  def capture_env(keys) when is_list(keys) do
    captures = for key <- keys, do: {key, Application.get_env(:historian, key)}

    fn ->
      for {key, value} <- captures do
        Application.put_env(:historian, key, value)
      end
    end
  end

  def capture_env(key) do
    value = Application.get_env(:historian, key)
    fn -> Application.put_env(:historian, key, value) end
  end
end
