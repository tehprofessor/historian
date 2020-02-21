defmodule Historian.UserInterface do
  @moduledoc "Manages the state of the User Interface including the page buffer to use and color scheme."

  defstruct [:page_buffer, page_ref: nil, output_mode: 0]

  use GenServer

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    ui_state = %__MODULE__{page_buffer: nil, page_ref: nil}
    scheme = Application.get_env(:historian, :color_scheme, nil)
    _ = set_color_scheme!(scheme)

    {:ok, ui_state}
  end

  @doc """
  Get the current page buffer in the `#{inspect(__MODULE__)}` process.

  Returns:
    - `{:ok, page_buffer_pid}` - Success result.
    - `{:error, :dead_pid}` - Page buffer process is nothing but a dreadful reminder of our endless march
    towards death and being forgotten.
    - `{:error, :stale_pid}` - Reference belongs to a stale pid, if you do not care about the old pid, you can call
    this function with `nil` and it will return whatever the current pid is bypassing the reference check.

  ## Parameters

    - page_ref: The reference returned when setting the page buffer or `nil` to skip stale ref check.
  """
  @spec get(page_ref :: reference() | nil) ::
          {:ok, page_buffer_pid :: pid()} | {:error, :dead_pid} | {:error, :stale_reference}
  def get(nil) do
    GenServer.call(__MODULE__, :get)
  end

  def get(page_ref) do
    GenServer.call(__MODULE__, {:get, page_ref})
  end

  def update_color_scheme(color_scheme) do
    set_color_scheme!(color_scheme)
  end

  @doc """
  Sets the page buffer in the `#{inspect(__MODULE__)}` process, returns `{:ok, ref}` if the process has been
  successfully set or `{:error, :dead_pid}` if the process's spark of life has been smothered in shite...

  ## Parameters

    - pager: The pid for a `Historian.PageBuffer` process.
  """
  @spec set(page_buffer_pid :: pid()) :: {:ok, reference()} | {:error, :dead_pid}
  def set(page_buffer_pid) do
    GenServer.call(__MODULE__, {:set, page_buffer_pid})
  end

  # - GenServer

  def handle_call(:get, _from, %{page_buffer: page_buffer} = ui_state) do
    if Process.alive?(page_buffer) do
      {:reply, {:ok, page_buffer}, ui_state}
    else
      {:reply, {:error, :dead_pid}, ui_state}
    end
  end

  def handle_call(
        {:get, page_ref},
        _from,
        %{page_pref: page_ref, page_buffer: page_buffer} = ui_state
      ) do
    if Process.alive?(page_buffer) do
      {:reply, {:ok, page_buffer}, ui_state}
    else
      {:reply, {:error, :dead_pid}, ui_state}
    end
  end

  def handle_call({:get, _stale_ref}, _from, ui_state) do
    {:reply, {:error, :stale_reference}, ui_state}
  end

  def handle_call({:set, pb_pid}, _from, ui_state) do
    if Process.alive?(pb_pid) do
      pb_ref = make_ref()
      {:reply, {:ok, pb_ref}, %{ui_state | page_buffer: pb_pid, page_ref: pb_ref}}
    else
      {:reply, {:error, :dead_pid}, ui_state}
    end
  end

  def set_color_scheme!(scheme) do
    colors = Historian.Styles.color_scheme(scheme)
    Application.put_env(:historian, :colors, colors)
  end
end
