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

  @spec create(list({iolist(), non_neg_integer()}), atom()) :: t(Item.t())
  def create(lines, name \\ :default) do
    for {line, index} <- lines, reduce: %__MODULE__{name: name} do
      instance ->
        item = %Item{id: index, value: strip_line(line), __meta__: %{length: length(line)}}
        %{instance | items: [item | instance.items]}
    end
  end

  @doc """
  Search the history buffer's values matching the pattern, and return only the matching items.
  """
  @spec search!(history :: t(Item.t()), pattern :: Regex.t()) :: list(Item.t())
  def search!(history, pattern) do
    Enum.filter(history.items, fn item -> item.value =~ pattern end)
  end

  @doc """
  Search the history buffer's values matching the pattern, and return an updated History buffer containing only the
  matching items.
  """
  @spec search(history :: t(Item.t()), pattern :: Regex.t()) :: t(Item.t())
  def search(history, pattern) do
    %{history | items: search!(history, pattern)}
  end

  @doc """
  Slice the history buffer's using the given bounds, and return a list containing only the sliced items.
  """
  @spec slice(history :: t(Item.t()), start :: non_neg_integer(), stop :: integer()) :: t(Item.t())
  def slice(history, start, stop) do
    %{history | items: slice!(history, start, stop)}
  end

  @doc """
  Slice the history buffer's using the given bounds, and return an updated buffer containing only the sliced items.
  """
  @spec slice!(history :: t(Item.t()), start :: non_neg_integer(), stop :: integer()) :: list(Item.t())
  def slice!(history, start, stop) do
    Enum.filter(history.items, fn %{id: id} -> Enum.member?(start..stop, id) end)
  end

  @doc """
  Pluck takes a list of line ids returning an updated history buffer containing only lines coresponding to the ids.
  """
  def pluck(history, indexes) do
    %{history | items: pluck!(history, indexes)}
  end

  @doc """
  Pluck takes a list of line numbers returning a list containing only lines coresponding to the matching ids (or an
  empty list if there are no matches).
  """
  @spec pluck!(history :: t(Item.t()), line_numbers :: list(non_neg_integer())) :: list(Item.t())
  def pluck!(history, line_numbers) when is_list(line_numbers) do
    Enum.map(line_numbers, fn index ->
      Enum.find(history.items, &(&1.id == index))
    end)
  end

  # Note: This exists mostly as a developer convenience as it's really easy to type `pluck(history, 33)` after you've
  # been pluckin' around a while and then getting an error because you didn't wrap the line number is quite annoying.
  @spec pluck!(history :: t(Item.t()), line_number :: non_neg_integer()) :: t(Item.t())
  def pluck!(history, line_number) do
    case line_at(history, line_number) do
      nil -> []
      line -> [line]
    end
  end

  @doc """
  Returns a line from the history buffer by it's index.
  """
  @spec line_at(history :: t(Item.t()), index :: non_neg_integer()) :: Item.t() | nil
  def line_at(%{items: items} = history, index) do
    Enum.at(items, index)
  end

  defp strip_line(line) do
    String.replace(to_string(line), "\n", "")
  end
end
