defmodule Historian.UserInterfaceServer do
  @moduledoc false

  use GenServer

  def start_link(initial_screen, _opts \\ []) do
    GenServer.start_link(__MODULE__, initial_screen, name: __MODULE__)
  end

  def init(initial_screen) do
    interface_state = %{screen: initial_screen, start_screen: initial_screen}

    {:ok, interface_state}
  end

  def start_screen() do
    GenServer.call(__MODULE__, :start_screen)
  end

  def handle_call(:start_screen, _from, state) do
    {:reply, state.start_screen, state}
  end
end
