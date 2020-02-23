defmodule Historian.UserInterface do
  @moduledoc "Manages the state of the User Interface including the page buffer to use and color scheme."

  defstruct [:page_buffer, page_ref: nil, output_mode: 0, initial_screen: :view_history]

  use GenServer

  # This is an incomplete list of what GenServer.call accepts but it's all Historian uses.
  @type server :: pid | atom()

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(_) do
    ui_state = %__MODULE__{page_buffer: nil, page_ref: nil}
    scheme = Application.get_env(:historian, :color_scheme, :default)
    _ = set_color_scheme!(scheme)

    {:ok, ui_state}
  end

  @spec current_session(server()) :: {:ok, reference()} | {:error, :no_session_prepared}
  def current_session(server \\ __MODULE__) do
    GenServer.call(server, :current_session)
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

    - server: [optional] UI process to call (defaults to process named: #{__MODULE__})
    - page_ref: The reference returned when setting the page buffer or `nil` to skip stale ref check.
  """
  @spec get(server(), page_ref :: reference() | nil) ::
          {:ok, page_buffer_pid :: pid()} | {:error, :dead_pid} | {:error, :stale_reference}
  def get(server \\ __MODULE__, page_ref)

  def get(server, nil) do
    GenServer.call(server, :get)
  end

  def get(server, page_ref) do
    GenServer.call(server, {:get, page_ref})
  end

  def update_color_scheme(color_scheme) do
    set_color_scheme!(color_scheme)
  end

  @doc """
  Sets the page buffer in the `#{inspect(__MODULE__)}` process, returns `{:ok, ref}` if the process has been
  successfully set or `{:error, :dead_pid}` if the process's spark of life has been smothered in shite...

  ## Parameters

    - server: [optional] UI process to call (defaults to process named: #{__MODULE__})
    - pager: The pid for a `Historian.PageBuffer` process.
  """
  @spec set(server(), page_buffer_pid :: pid()) :: {:ok, reference()} | {:error, :dead_pid}
  def set(server \\ __MODULE__, page_buffer_pid) do
    GenServer.call(server, {:set, page_buffer_pid})
  end

  @spec prepare_session(server(), screen_name :: :archive | :view_history) ::
          {:ok, session_ref :: reference()}
  def prepare_session(server \\ __MODULE__, screen_name) do
    GenServer.call(server, {:prepare_session, screen_name})
  end

  @spec session_info(server(), session_ref :: reference()) ::
          {:ok, map()} | {:error, :invalid_session_ref}
  def session_info(server \\ __MODULE__, session_ref) do
    GenServer.call(server, {:get_session_info, session_ref})
  end

  # - GenServer

  def handle_call(:current_session, _from, ui_state) do
    maybe_session =
      with %{initial_screen: {_screen_name, session_ref}} <- ui_state do
        {:ok, session_ref}
      else
        _invalid_session -> {:error, :no_session_prepared}
      end

    {:reply, maybe_session, ui_state}
  end

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

  def handle_call({:get_session_info, session_ref}, _from, ui_state) do
    maybe_session =
      with %{initial_screen: {screen_name, ^session_ref}} <- ui_state do
        {:ok, %{initial_screen: screen_name}}
      else
        _invalid_session -> {:error, :invalid_session_ref}
      end

    {:reply, maybe_session, ui_state}
  end

  def handle_call({:prepare_session, screen_name}, _from, ui_state) do
    session = make_ref()
    {:reply, {:ok, session}, %{ui_state | initial_screen: {screen_name, session}}}
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
