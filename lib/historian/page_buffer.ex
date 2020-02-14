defmodule Historian.PageBuffer do
  @moduledoc """
  A buffer to manage paging your history... by "snapshotting" when the buffer was created.
  """

  alias Historian.History

  defstruct [:page_size, :total_pages, :offset, :page, :table, :item_count, :ref]

  @type t() :: %__MODULE__{
                 item_count: non_neg_integer(),
                 offset: non_neg_integer(),
                 page: non_neg_integer(),
                 page_size: pos_integer(),
                 ref: reference(),
                 table: pos_integer(),
                 total_pages: non_neg_integer()
               }

  @type page_result :: {:ok, History.t()} | {:ok, :done}

  @spec current(page_buffer_pid :: pid()) :: page_result()
  def current(pager) do
    GenServer.call(pager, {:get, :current_page})
  end

  @spec get(page_buffer_pid :: pid(), pos_integer()) :: page_result()
  def get(pager, page_number) do
    GenServer.call(pager, {:get, page_number})
  end

  @spec get_line(page_buffer_pid :: pid(), line_number :: non_neg_integer()) :: page_result()
  def get_line(pager, line_number) do
    GenServer.call(pager, {:get_line, line_number})
  end

  @spec first(page_buffer_pid :: pid()) :: page_result()
  def first(pager) do
    GenServer.call(pager, 0)
  end

  @spec info(page_buffer_pid :: pid()) :: t()
  def info(pager) do
    GenServer.call(pager, :pager_info)
  end

  @spec last(page_buffer_pid :: pid()) :: page_result()
  def last(pager) do
    GenServer.call(pager, :last_page)
  end

  @spec next(page_buffer_pid :: pid()) :: page_result()
  def next(pager) do
    GenServer.call(pager, :next_page)
  end

  @spec set_page(page_buffer_pid :: pid(), pos_integer()) :: page_result()
  def set_page(pager, page) do
    GenServer.call(pager, {:set_page, page})
  end

  # - GenServer

  def start_link(page_size, _opts \\ []) do
    GenServer.start_link(__MODULE__, page_size)
  end

  def init(page_size) do
    table = :ets.new(__MODULE__, [:ordered_set, :public, {:write_concurrency, true}])
    instance = %__MODULE__{page: 0, offset: 0, page_size: page_size, table: table, ref: make_ref()}

    {:ok, instance, {:continue, :sync_history}}
  end

  def handle_continue(:sync_history, state) do
    {:ok, updated_state} =
      :group_history.load()
      |> Enum.with_index(0)
      |> Enum.reverse()
      |> History.create()
      |> initialize_pages(state)

    {:noreply, updated_state}
  end

  def handle_call({:get, :current_page}, from, %{page: page} = state) do
    handle_call({:get, page}, from, state)
  end

  def handle_call({:get, :last_page}, from, %{total_pages: page} = state) do
    handle_call({:get, page - 1}, from, state)
  end

  def handle_call({:get, page}, _from, %{table: table} = state) do
    result = get_page(table, page)

    {:reply, result, state}
  end

  def handle_call({:get_line, :infinity}, _from, %{table: table, total_pages: page} = state) do
    {:ok, history} = get_page(table, page - 1)
    result = List.last(history.items)

    {:reply, result, state}
  end

  def handle_call({:get_line, 0}, _from, %{table: table} = state) do
    {:ok, page} = get_page(table, 0)

    result = Enum.find(page.items, &(&1.id == 0))

    {:reply, result, state}
  end

  def handle_call({:get_line, line_number}, _from, %{table: table, page_size: page_size} = state) do
    page_number =
      if Integer.mod(page_size, line_number) == 0,
         do: div(line_number, page_size),
         else: div(line_number, page_size)

    {:ok, page} = get_page(table, page_number)

    result = Enum.find(page.items, &(&1.id == line_number))

    {:reply, result, state}
  end

  def handle_call(:next_page, _from, %{page: page} = state) do
    state = %{state | page: page + 1}
    result = get_page(state.table, state.page)

    {:reply, result, state}
  end

  def handle_call(:pager_info, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:set_page, page}, _from, %{table: table} = state) do
    result = get_page(table, page)

    {:reply, result, %{state | page: page}}
  end

  # - Private

  defp get_page(table, page) do
    case :ets.lookup(table, page) do
      [] -> {:ok, :done}
      [{_index, result}] -> {:ok, %History{items: result}}
    end
  end

  defp initialize_pages(%History{items: items}, %{page_size: page_size} = state) do
    item_count = Enum.count(items)

    total_pages =
      if Integer.mod(page_size, item_count) == 0,
        do: div(item_count, page_size),
        else: div(item_count, page_size) + 1

    instance = %{state | item_count: item_count, total_pages: total_pages}

    Enum.chunk_every(items, page_size)
    |> Enum.with_index(0)
    |> Enum.map(fn {chunk, index} ->
      :ets.insert(instance.table, {index, chunk})
    end)

    {:ok, instance}
  end
end
