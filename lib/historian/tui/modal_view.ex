defmodule Historian.TUi.ModalView do
  @moduledoc """
  Creates modal or overlay views (primarily used by the archiving system)
  """

  alias Historian.TerminalUI.Cursor

  import Historian.Gettext
  import Ratatouille.View

  @background_color :white
  @color :black

  @txt_cancel "Cancel"
  @txt_content "Content"
  @txt_editing_entry "EDITING ENTRY!"
  @txt_save "Save"
  @txt_name "Name"

  @text_block_cursor_char "|"

  def dialog_box(title, heading, confirm, dismiss, height \\ 10, cursor \\ %Cursor{}, do: body) do
    overlay do
      panel title: title, height: height, color: @color, background: @background_color do
        row do
          column(size: 12) do
            focusable_element(0, cursor, {:name_panel, heading})
          end
        end

        row do
          column(size: 12) do
            body
          end
        end

        row do
          column(size: 1) do
            focusable_element(2, cursor, {:text, dismiss}, color: :red)
          end

          column(size: 1) do
            focusable_element(3, cursor, {:text, confirm}, color: :cyan)
          end

          column(size: 10) do
            label(content: "")
          end
        end
      end
    end
  end

  def edit_dialog_box(heading, content, rows, cursor, element_cursor) do
    dialog_box(
      gettext(@txt_editing_entry),
      heading,
      gettext(@txt_save),
      gettext(@txt_cancel),
      15,
      element_cursor
    ) do
      do_edit_dialog_box(content, rows, cursor, element_cursor)
    end
  end

  defp do_edit_dialog_box(content, rows, cursor, element_cursor) do
    viewable_lines = viewable_content(content, rows, cursor)
    focusable_element(1, element_cursor, {:content_panel, viewable_lines})
  end

  def focusable_element(index, cursor, {:text, text}, opts) do
    color = Keyword.fetch!(opts, :color)
    Cursor.selected?(cursor, index) |> highlight_element(text, color)
  end

  def focusable_element(index, %{cursor: index}, {:content_panel, viewable_lines}) do
    content_element = label(content: viewable_lines <> @text_block_cursor_char, color: :yellow)
    edit_content_panel(:yellow, content_element)
  end

  def focusable_element(_index, %{cursor: _position}, {:content_panel, viewable_lines}) do
    content_element = label(content: viewable_lines, color: :yellow)
    edit_content_panel(:white, content_element)
  end

  def focusable_element(index, %{cursor: index}, {:name_panel, entry_name}) do
    name_element = label(content: entry_name <> @text_block_cursor_char, color: :yellow)
    edit_name_panel(:yellow, name_element)
  end

  def focusable_element(_index, %{cursor: _position}, {:name_panel, entry_name}) do
    name_element = label(content: entry_name, color: :yellow)
    edit_name_panel(:white, name_element)
  end

  def highlight_element(true, text, :cyan) do
    highlight_element(true, text, :black)
  end

  def highlight_element(true, text, color) do
    label(content: text, color: color, background: :yellow, attributes: [:bold, :underline])
  end

  def highlight_element(_falsy, text, color) do
    label(content: text, color: color, attributes: [:bold])
  end

  defp viewable_content(content, rows, %{cursor: text_cursor}) do
    {hidden, viewable} = String.split(content, "\n") |> Enum.split(text_cursor)
    number_viewable = Enum.count(viewable)

    if number_viewable > rows do
      Enum.slice(viewable, 0, rows)
    else
      hidden_items_offset = text_cursor - number_viewable
      back_fill = Enum.slice(hidden, hidden_items_offset, rows - number_viewable)
      back_fill ++ viewable
    end
    |> Enum.join("\n")
  end

  defp edit_name_panel(panel_bg, content) do
    panel_title = gettext(@txt_name)

    panel title: panel_title,
          background: panel_bg,
          color: :black,
          attributes: [:bold] do
      content
    end
  end

  defp edit_content_panel(panel_bg, content) do
    title_text = gettext(@txt_content)

    row do
      column(size: 12) do
        row do
          column(size: 12) do
            panel title: title_text,
                  background: panel_bg,
                  color: :black,
                  attributes: [:bold],
                  height: :fill do
              viewport(offset_y: 0) do
                content
              end
            end
          end
        end
      end
    end
  end
end
