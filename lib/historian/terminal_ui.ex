defmodule Historian.TerminalUI do
  @behaviour Ratatouille.App

  alias Historian.{Archive, Clipboard, History, PageBuffer, TUi, UserInterface}

  import Ratatouille.Constants, only: [key: 1]

  @spacebar key(:space)

  @enter key(:enter)

  @delete_keys [
    key(:delete),
    key(:backspace),
    key(:backspace2)
  ]

  defstruct [:history, :cursor, :screen, :data, :last_event]

  defmodule HistoryViewModel do
    alias Historian.TerminalUI.Cursor

    defstruct [:items, :cursor, :selected_lines]

    def new(items) do
      max_length = Enum.count(items)
      cursor = Cursor.new(:history_view_model, max_length)
      %__MODULE__{items: items, cursor: cursor, selected_lines: []}
    end
  end

  defmodule ArchiveItemFormViewModel do
    alias Historian.TerminalUI.Cursor

    defstruct [:cursor, :source, :object, :element_cursor]

    def new(%{items: item} = source) when is_binary(item) do
      source = %{source | items: [item]}

      do_new(source, 1)
    end

    def new(%{items: items} = source) do
      size = Enum.count(items)

      do_new(source, size)
    end

    defp do_new(source, size, element_size \\ 4) do
      %__MODULE__{
        cursor: Cursor.new(:edit_cursor, size),
        element_cursor: Cursor.new(:element_cursor, element_size),
        object: source,
        source: source
      }
    end
  end

  defmodule Cursor do
    defstruct [:cursor, :size, :id, :loop]

    def new(id, size) do
      %__MODULE__{id: id, size: size, cursor: 0, loop: false}
    end

    def value_at(items, %{cursor: cursor}) do
      Enum.at(items, cursor)
    end

    def position(%{cursor: cursor}) do
      cursor
    end

    def up(%{cursor: cursor} = instance) do
      %{instance | cursor: max(cursor - 1, 0)}
    end

    def up!(%{cursor: cursor} = model) do
      %{model | cursor: up(cursor)}
    end

    def down(%{cursor: cursor, size: size} = instance) do
      %{instance | cursor: min(cursor + 1, size - 1)}
    end

    def down!(%{cursor: cursor} = model) do
      %{model | cursor: down(cursor)}
    end

    def selected?(%{cursor: cursor}, cursor), do: true

    def selected?(%{cursor: _cursor}, _not_matching), do: false
  end

  defmodule ArchiveViewModel do
    alias Historian.TerminalUI.Cursor

    defstruct [:items, :cursor]

    def new(items) do
      max_length = Enum.count(items)
      cursor = Cursor.new(:archive_view, max_length)
      %__MODULE__{items: items, cursor: cursor}
    end
  end

  defmodule SearchViewModel do
    alias Historian.TerminalUI.Cursor

    defstruct [:term, :items, :pattern, :cursor]

    def new(%{items: items}, "") do
      max_length = Enum.count(items)
      cursor = Cursor.new(:search_view, max_length)
      %__MODULE__{items: items, term: "", pattern: ~r//, cursor: cursor}
    end

    def new(history, term) do
      {:ok, pattern} = Regex.escape(term) |> Regex.compile()
      items = History.search!(history, pattern)
      max_length = Enum.count(items)
      cursor = Cursor.new(:search_view, max_length)
      %__MODULE__{items: items, term: term, pattern: pattern, cursor: cursor}
    end
  end

  def init(_) do
    # This is in need of some cleanup..
    if Historian.Archive.configured?() do
      history = page_buffer()

      view_data = HistoryViewModel.new(history.items)
      screen_nav_cursor = Cursor.new(:screen_nav, 2)

      default_state = %__MODULE__{
        history: history,
        cursor: screen_nav_cursor,
        screen: :view_history,
        data: view_data
      }

      {:ok, session_ref} = UserInterface.current_session()

      case UserInterface.session_info(session_ref) do
        {:ok, %{initial_screen: :archive}} -> show_archive(default_state, screen_nav_cursor)
        _ -> default_state
      end
    else
      {:ok, window_height} = Ratatouille.Window.fetch(:height)

      %__MODULE__{
        history: nil,
        cursor: Cursor.new(:welcome, max(44 - window_height, 0)),
        screen: :welcome,
        data: %{}
      }
    end
  end

  def update(%{screen: :welcome} = state, msg) do
    case msg do
      {:event, %{ch: ?j}} ->
        Cursor.down!(state)

      {:event, %{ch: ?k}} ->
        Cursor.up!(state)

      {:event, %{key: @enter}} ->
        with {:ok, :setup_completed} <- Historian.Archive.setup!() do
          history = page_buffer()
          view_data = HistoryViewModel.new(history.items)
          screen_nav_cursor = Cursor.new(:screen_nav, 2)

          %__MODULE__{
            history: history,
            cursor: screen_nav_cursor,
            screen: :view_history,
            data: view_data
          }
        end

      {:event, %{ch: ?y}} ->
        %{state | last_event: :install}

      _ ->
        %{state | last_event: nil}
    end
  end

  def update(%{screen: :search, data: %{items: items}} = state, {:event, %{key: @enter}})
      when items != [] do
    %{state | last_event: :select_search}
  end

  def update(
        %{screen: :search, history: history, data: %{term: term}, last_event: nil} = state,
        message
      ) do
    new_term =
      case message do
        {:event, %{key: key}} when key in @delete_keys -> String.slice(term, 0..-2)
        {:event, %{key: @spacebar}} -> term <> " "
        {:event, %{ch: ch}} when ch > 0 -> term <> <<ch::utf8>>
        _ -> term
      end

    %{state | data: SearchViewModel.new(history, new_term)}
  end

  def update(%{cursor: cursor, screen: screen, last_event: nil} = state, {:event, %{ch: char}})
      when screen != :archive and char in [?a, ?2] do
    show_archive(state, cursor)
  end

  def update(
        %{cursor: cursor, screen: :search, last_event: last_event} = state,
        {:event, %{ch: char}}
      )
      when char in [?a, ?2] and last_event != nil do
    show_archive(state, cursor)
  end

  def update(%{screen: :search, last_event: :copied_line} = state, msg) do
    update(%{state | last_event: :select_search}, msg)
  end

  def update(
        %{screen: :search, cursor: cursor, history: history, last_event: :select_search} = state,
        {:event, %{ch: ?s}}
      ) do
    show_view_history(state, history.items, cursor)
  end

  def update(%{screen: :search, data: model, last_event: :select_search} = state, msg) do
    {event, updated_model} =
      case msg do
        {:event, %{ch: ?e}} -> {nil, model}
        {:event, %{ch: ?j}} -> move_down(model)
        {:event, %{ch: ?k}} -> move_up(model)
        {:event, %{ch: ?y}} -> copy_to_clipboard(model, model.cursor.cursor, [])
        _ -> {:select_search, model}
      end

    %{state | data: updated_model, last_event: event}
  end

  def update(%{screen: screen, history: history} = state, {:event, %{ch: ?s}})
      when screen not in [:search, :archive] do
    %{state | screen: :search, data: SearchViewModel.new(history, ""), last_event: nil}
  end

  def update(
        %{cursor: cursor, screen: screen, history: %{items: items}, last_event: nil} = state,
        {:event, %{ch: ?1}}
      )
      when screen not in [:view_history, :search] do
    cursor =
      if Cursor.selected?(cursor, 0) do
        cursor
      else
        Cursor.up(cursor)
      end

    %{
      state
      | screen: :view_history,
        data: HistoryViewModel.new(items),
        last_event: nil,
        cursor: cursor
    }
  end

  def update(%{screen: :archive, last_event: {:editing_entry, edit_item}} = state, msg) do
    case Historian.TUi.ArchiveItemForm.handle_event(msg, {:editing_entry, edit_item}) do
      {:editing_entry_save, _} = save_event -> update(%{state | last_event: save_event}, msg)
      {event, updated_item} -> %{state | last_event: {event, updated_item}}
    end
  end

  def update(%{screen: :archive, last_event: {:new_entry, edit_item}} = state, msg) do
    case Historian.TUi.ArchiveItemForm.handle_event(msg, {:new_entry, edit_item}) do
      {:new_entry_save, _} = save_event -> update(%{state | last_event: save_event}, msg)
      {event, updated_item} -> %{state | last_event: {event, updated_item}}
    end
  end

  def update(%{screen: :archive, last_event: {:new_entry_save, %{name: name}}} = state, _msg) do
    archive_data = Archive.all()
    %{state | data: ArchiveViewModel.new(archive_data), last_event: {:updated_entry, name}}
  end

  def update(%{screen: :archive, last_event: {:editing_entry_save, %{name: name}}} = state, _msg) do
    archive_data = Archive.all()
    %{state | data: ArchiveViewModel.new(archive_data), last_event: {:updated_entry, name}}
  end

  def update(%{screen: :archive, data: model} = state, msg) do
    {event, updated_model} =
      case msg do
        {:event, %{ch: ?j}} ->
          move_down(model)

        {:event, %{ch: ?k}} ->
          move_up(model)

        {:event, %{ch: ?y}} ->
          copy_to_clipboard(model, model.cursor.cursor, [])

        {:event, %{ch: ?n}} ->
          new_item(model)

        {:event, %{ch: ?e}} ->
          if model.items == [] do
            new_item(model)
          else
            edit_item(model)
          end

        _ ->
          {nil, model}
      end

    %{state | data: updated_model, last_event: event}
  end

  def update(%{screen: :view_history, data: nil, history: %{items: items}} = state, msg) do
    update(%{state | data: HistoryViewModel.new(items)}, msg)
  end

  def update(
        %{
          screen: :view_history,
          data: %{cursor: %{cursor: cursor}, selected_lines: selected_lines} = model
        } = state,
        msg
      ) do
    selected = cursor

    {event, updated_model} =
      case msg do
        {:event, %{ch: ?j}} -> move_down(model)
        {:event, %{ch: ?k}} -> move_up(model)
        {:event, %{key: @spacebar}} -> select_line(model, selected, selected_lines)
        {:event, %{ch: ?y}} -> copy_to_clipboard(model, selected, selected_lines)
        {:event, %{ch: ?Y}} -> copy_to_clipboard(model, selected, selected_lines, " \\\n")
        _ -> {nil, model}
      end

    %{state | data: updated_model, last_event: event}
  end

  def render(%{screen: :welcome} = model) do
    TUi.Welcome.render(model)
  end

  def render(%{screen: :view_history} = model) do
    TUi.HistoryView.render(model)
  end

  def render(%{screen: :archive} = model) do
    TUi.ArchiveView.render(model)
  end

  def render(%{screen: :search, last_event: :copied_line} = state) do
    TUi.Search.render(state)
  end

  def render(%{screen: :search, last_event: :select_search} = state) do
    TUi.Search.render(state)
  end

  def render(%{screen: :search, last_event: _} = state) do
    TUi.Search.render(state)
  end

  # - Actions
  defp edit_item(%ArchiveViewModel{items: items, cursor: cursor} = model) do
    item = Cursor.value_at(items, cursor)
    edit_item_model = ArchiveItemFormViewModel.new(item)

    {{:editing_entry, edit_item_model}, model}
  end

  defp new_item(%ArchiveViewModel{} = model) do
    item = Archive.Item.new(:empty, [""])
    edit_item_model = ArchiveItemFormViewModel.new(item)

    {{:new_entry, edit_item_model}, model}
  end

  defp move_up(%HistoryViewModel{} = model) do
    {nil, Cursor.up!(model)}
  end

  defp move_up(%ArchiveViewModel{} = model) do
    {nil, Cursor.up!(model)}
  end

  defp move_up(%SearchViewModel{} = model) do
    {:select_search, Cursor.up!(model)}
  end

  defp move_down(%HistoryViewModel{} = model) do
    {nil, Cursor.down!(model)}
  end

  defp move_down(%ArchiveViewModel{} = model) do
    {nil, Cursor.down!(model)}
  end

  defp move_down(%SearchViewModel{} = model) do
    {:select_search, Cursor.down!(model)}
  end

  defp select_line(model, selected, []) do
    {:select_line, %{model | selected_lines: [selected]}}
  end

  defp select_line(model, selected, selected_lines) do
    selected_lines =
      if selected in selected_lines,
        do: List.delete(selected_lines, selected),
        else: [selected | selected_lines]

    {:select_line, %{model | selected_lines: selected_lines}}
  end

  # TODO: Cleanup args here... `selected_lines` is redundant, it should be
  # present if available in the model...
  defp copy_to_clipboard(model, selected, selected_lines, joiner \\ "\n")

  defp copy_to_clipboard(%HistoryViewModel{} = model, selected, [], _joiner) do
    item = Enum.find(model.items, &(&1.id == selected))
    _ = Clipboard.copy(item.value)

    {:copied_line, model}
  end

  defp copy_to_clipboard(%HistoryViewModel{} = model, _selected, selected_lines, joiner) do
    lines = for item <- model.items, item.id in selected_lines, do: item.value
    value = Enum.join(lines, joiner)
    _ = Clipboard.copy(value)

    {:copied_lines, %{model | selected_lines: []}}
  end

  defp copy_to_clipboard(%SearchViewModel{} = model, selected, [], _joiner) do
    item = Enum.at(model.items, selected)
    _ = Clipboard.copy(item.value)

    {:copied_line, model}
  end

  defp copy_to_clipboard(%ArchiveViewModel{} = model, selected, [], joiner) do
    %{items: values} = Enum.at(model.items, selected)
    value = if is_list(values), do: Enum.join(values, joiner), else: values
    _ = Clipboard.copy(value)

    {:copied_line, model}
  end

  defp page_buffer() do
    with {:ok, pager} <- Historian.UserInterface.get(nil),
         {:ok, history} = PageBuffer.current(pager) do
      history
    end
  end

  defp show_archive(state, cursor) do
    archive_data = Archive.all()

    cursor =
      if Cursor.selected?(cursor, 1) do
        cursor
      else
        Cursor.down(cursor)
      end

    %{
      state
      | screen: :archive,
        data: ArchiveViewModel.new(archive_data),
        last_event: nil,
        cursor: cursor
    }
  end

  defp show_view_history(state, items, cursor) do
    %{
      state
      | screen: :view_history,
        data: HistoryViewModel.new(items),
        last_event: nil,
        cursor: cursor
    }
  end
end
