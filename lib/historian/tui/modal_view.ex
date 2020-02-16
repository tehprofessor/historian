defmodule Historian.TUi.ModalView do
  @moduledoc """
  Creates modal or overlay views (primarily used by the archiving system)
  """

  alias Historian.Config
  alias Historian.TerminalUI.Cursor

  import Historian.Gettext
  import Ratatouille.View

  @txt_cancel "Cancel"
  @txt_content "Content"
  @txt_editing_entry "EDITING ENTRY!"
  @txt_new_entry "NEW ENTRY!"
  @txt_save "Save"
  @txt_name "Name"

  @text_block_cursor_char "|"

  def dialog_box(title, heading, confirm, dismiss, height \\ 10, cursor \\ %Cursor{}, do: body) do
    dialog_box_confirm_color = Config.color(:dialog_box_confirm_text, :cyan)
    dialog_box_cancel_color = Config.color(:dialog_box_cancel_text, :red)
    dialog_box_bg_color = Config.color(:dialog_box_background, :white)
    dialog_box_text_color = Config.color(:dialog_box_text, :black)

    overlay do
      panel title: title, height: height, color: dialog_box_text_color, background: dialog_box_bg_color do
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
            focusable_element(2, cursor, {:text, dismiss}, color: dialog_box_cancel_color)
          end

          column(size: 1) do
            focusable_element(3, cursor, {:text, confirm}, color: dialog_box_confirm_color)
          end

          column(size: 10) do
            label(content: "")
          end
        end
      end
    end
  end

  def new_dialog_box(heading, content, rows, cursor, element_cursor) do
    dialog_box(
      gettext(@txt_new_entry),
      heading,
      gettext(@txt_save),
      gettext(@txt_cancel),
      15,
      element_cursor
    ) do
      do_edit_dialog_box(content, rows, cursor, element_cursor)
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
    label_background_selected_color = Config.color(:dialog_box_label_background_selected, :yellow)
    label_content_text = Config.color(:dialog_box_label_content_text, :yellow)

    content_element = label(content: viewable_lines <> @text_block_cursor_char, color: label_content_text)
    edit_content_panel(label_background_selected_color, content_element)
  end

  def focusable_element(_index, %{cursor: _position}, {:content_panel, viewable_lines}) do
    label_background_color = Config.color(:dialog_box_label_background, :white)
    label_content_text = Config.color(:dialog_box_label_content_text, :yellow)

    content_element = label(content: viewable_lines, color: label_content_text)
    edit_content_panel(label_background_color, content_element)
  end

  def focusable_element(index, %{cursor: index}, {:name_panel, entry_name}) do
    label_background_selected_color = Config.color(:dialog_box_label_background_selected, :yellow)
    label_content_text = Config.color(:dialog_box_label_content_text, :yellow)

    name_element = label(content: entry_name <> @text_block_cursor_char, color: label_content_text)

    edit_name_panel(label_background_selected_color, name_element)
  end

  def focusable_element(_index, %{cursor: _position}, {:name_panel, entry_name}) do
    label_background_color = Config.color(:dialog_box_label_background, :white)
    label_content_text = Config.color(:dialog_box_label_content_text, :yellow)

    name_element = label(content: entry_name, color: label_content_text)

    edit_name_panel(label_background_color, name_element)
  end

  def highlight_element(true, text, :cyan) do
    highlight_element(true, text, :black)
  end

  def highlight_element(true, text, color) do
    dialog_box_selected_element_background = Config.color(:dialog_box_selected_element, :yellow)
    label(content: text, color: color, background: dialog_box_selected_element_background, attributes: [:bold, :underline])
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
    panel_text_color = Config.color(:dialog_box_content_panel_text, :black)

    panel title: panel_title,
          background: panel_bg,
          color: panel_text_color,
          attributes: [:bold] do
      content
    end
  end

  defp edit_content_panel(panel_bg, content) do
    title_text = gettext(@txt_content)
    panel_text_color = Config.color(:dialog_box_content_panel_text, :black)

    row do
      column(size: 12) do
        row do
          column(size: 12) do
            panel title: title_text,
                  background: panel_bg,
                  color: panel_text_color,
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
