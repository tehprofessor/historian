defmodule Historian.History do
  @moduledoc """
  A data structure for managing histories.
  """

  defstruct name: nil, items: [], __meta__: %{}

  @type t(item) :: %__MODULE__{name: atom(), items: list(item), __meta__: map()}

  defmodule Item do
    @moduledoc "A data structure and functions for history items."

    defstruct id: nil, value: nil, __meta__: %{}

    @type t :: %__MODULE__{id: non_neg_integer(), value: String.t(), __meta__: map()}
  end

  @spec create(list(String.t()), atom()) :: t(Item.t())
  def create(lines, name \\ :default) do
    for {line, index} <- Enum.with_index(lines), reduce: %__MODULE__{name: name} do
      instance ->
        item = %Item{id: index, value: strip_line(line), __meta__: %{length: length(line)}}
        %{instance | items: [item | instance.items]}
    end
  end

  @spec search(t(Item.t()), Regex.t()) :: list(Item.t())
  def search(history, pattern) do
    Enum.filter(history.items, fn item -> item.value =~ pattern end)
  end

  def search!(history, term) do
    %{history | items: search(history, term)}
  end

  def slice(history, start, stop) do
    %{history | items: slice!(history, start, stop)}
  end

  def slice!(history, start, stop) do
    Enum.filter(history.items, fn %{id: id} -> Enum.member?(start..stop, id) end)
  end

  def pluck(history, indexes) when is_list(indexes) do
    %{history | items: pluck!(history, indexes)}
  end

  def pluck!(history, indexes) when is_list(indexes) do
    Enum.map(indexes, fn index ->
      Enum.find(history.items, &(&1.id == index))
    end)
  end

  defp strip_line(line) do
    String.replace(to_string(line), "\n", "")
  end
end
