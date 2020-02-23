defmodule Historian.UserInterfaceTest do
  use ExUnit.Case

  alias Historian.UserInterface

  describe "sessions" do
    setup do
      {:ok, ui_server} = UserInterface.start_link()
      {:ok, %{ui_server: ui_server}}
    end

    test "prepare_session/2 - returns {:ok, session_ref}", %{ui_server: ui_server} do
      assert {:ok, ref} = UserInterface.prepare_session(ui_server, :view_history)
      assert is_reference(ref)
    end

    test "current_session/1 - returns {:ok, current_session}", %{ui_server: ui_server} do
      # First we must prepare a session
      assert {:ok, prepared_session_ref} = UserInterface.prepare_session(ui_server, :view_history)
      assert {:ok, ^prepared_session_ref} = UserInterface.current_session(ui_server)
      assert is_reference(prepared_session_ref)
    end

    test "current_session/1 - returns {:error, :no_session_prepared} no session has been prepared",
         %{ui_server: ui_server} do
      # First we must prepare a session
      assert {:error, :no_session_prepared} = UserInterface.current_session(ui_server)
    end

    test "session_info/2 - returns {:ok, session_info}", %{ui_server: ui_server} do
      # First we must prepare a session
      assert {:ok, session_ref} = UserInterface.prepare_session(ui_server, :archive)

      assert {:ok, %{initial_screen: :archive}} =
               UserInterface.session_info(ui_server, session_ref)
    end

    test "session_info/2 - returns {:error, :invalid_session_ref} if ref does not match the current one",
         %{ui_server: ui_server} do
      # First we must prepare a session
      assert {:ok, session_ref} = UserInterface.prepare_session(ui_server, :archive)
      assert {:error, :invalid_session_ref} = UserInterface.session_info(ui_server, make_ref())
    end
  end
end
