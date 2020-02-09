defmodule Historian.Buffer do
  @moduledoc """
  Ring buffer for holding managing the current history.

  Historian uses a ring buffer to store in-session history slices, providing the user a way to access previous
  slices in case they accidentally shit on their history between calls to slice.
  """

  defstruct [:max_size, :clock, :ref]

  #  @type t(item) :: %__MODULE__{items: list(item), max_size: pos_integer()}

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    _table_name =
      :ets.new(__MODULE__, [:named_table, :ordered_set, :public, {:write_concurrency, true}])

    instance = initialize_buffer()
    {:ok, instance}
  end

  def push(object) do
    GenServer.call(__MODULE__, {:push, object})
  end

  def list() do
    GenServer.call(__MODULE__, :list)
  end

  def first() do
    GenServer.call(__MODULE__, :list) |> List.first()
  end

  def handle_call({:push, object}, _from, buffer) do
    updated_buffer = do_push(buffer, object)

    {:reply, object, updated_buffer}
  end

  def handle_call(:list, _from, buffer) do
    {head, tail} = Enum.split((0..buffer.max_size), buffer.clock)
    indexes = Enum.reverse(head) ++ Enum.reverse(tail)

    results =
      for index <- indexes, reduce: [] do
        accum ->
          case :ets.lookup(__MODULE__, index) do
            [] -> accum
            [{^index, result}] -> [result | accum]
          end
      end

    {:reply, results, buffer}
  end

  defp initialize_buffer(max_size \\ 10) do
    instance = %__MODULE__{max_size: max_size, clock: 0, ref: make_ref()}
    :ets.insert(__MODULE__, {instance.ref, 0})
    instance
  end

  defp do_push(buffer, object) do
    new_clock = update_clock(buffer)
    _ = :ets.insert(__MODULE__, {new_clock, object})

    %{buffer | clock: new_clock}
  end

  defp update_clock(buffer) do
    :ets.update_counter(__MODULE__, buffer.ref, {2, 1, buffer.max_size, 0})
  end
end
