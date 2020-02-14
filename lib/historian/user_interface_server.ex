defmodule Historian.UserInterfaceServer do
  @moduledoc "This is probably useless..."

  use GenServer

  @scr_archive :archive
  @scr_search :search
  @scr_view_history :view_history
  @scr_welcome :welcome

  @screen_default @scr_welcome
  @screens [@scr_archive, @scr_search, @scr_view_history, @scr_welcome]

  @tr_initialize :initialize
  @tr_setup_completed :setup_completed

  @transitions [@tr_initialize, @tr_setup_completed]

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    ui_state = %{screen: @screen_default, first_screen: @screen_default, last_transition: nil}

    {:ok, ui_state}
  end

  @doc """
  Returns the current screen the user is on
  """
  @spec current() :: atom()
  def current() do
    GenServer.call(__MODULE__, :current)
  end

  def on_screen?(screen) when screen in @screens do
    nil # Maybe todo
  end

  @doc """
  Performs a state update to the UI server, tracking what to show the user.

  ## Parameters

    - name: An atom indicating which transition to perform, valid transitions are: #{inspect(@transitions)}
  """
  def transition(name) when name in @transitions do
    GenServer.call(__MODULE__, {:transition, name})
  end

  def first_screen() do
    GenServer.call(__MODULE__, :first_screen)
  end

  def handle_call(:current, _from, ui_state) do
    {:reply, ui_state.screen, ui_state}
  end

  def handle_call({:transition, event}, _from, ui_state) do
    ui_state = perform_transition(ui_state, event)
    {:reply, ui_state.screen, ui_state}
  end

  def handle_call(:first_screen, _from, ui_state) do
    {:reply, ui_state.first_screen, ui_state}
  end

  defp perform_transition(%{screen: nil} = ui_state, @tr_initialize) do
    %{ui_state | screen: @scr_welcome}
  end

  defp perform_transition(%{screen: @scr_welcome} = ui_state, @tr_setup_completed) do
    %{ui_state | screen: @scr_view_history}
  end

  defp perform_transition(%{screen: @scr_view_history} = ui_state, @tr_setup_completed) do
    ui_state
  end
end
