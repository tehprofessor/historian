defmodule Historian.TUi.Welcome do
  @moduledoc """
  Welcome Screen UI shown when running Historian for first time.
  """

  alias Historian.Config

  import Historian.Gettext
  import Historian.TUi.Elements
  import Ratatouille.View

  @historian_logo """
  ██╗  ██╗██╗███████╗████████╗ ██████╗ ██████╗ ██╗ █████╗ ███╗   ██╗
  ██║  ██║██║██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗██║██╔══██╗████╗  ██║
  ███████║██║███████╗   ██║   ██║   ██║██████╔╝██║███████║██╔██╗ ██║
  ██╔══██║██║╚════██║   ██║   ██║   ██║██╔══██╗██║██╔══██║██║╚██╗██║
  ██║  ██║██║███████║   ██║   ╚██████╔╝██║  ██║██║██║  ██║██║ ╚████║
  ╚═╝  ╚═╝╚═╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝
  [beta]

  An interactive history manager and snippet archival tool for IEx.
  """

  def welcome_text() do
    [
      label(content: "Welcome!\n", attributes: [:underline, :bold]),
      label do
        text(content: " It looks like this is the first time Historian has been run.")
      end,
      label(content: " Below you'll find instructions for how to setup an archive db;"),
      label(content: " if you would prefer not to or cannot persist the archive to disk,"),
      label(content: " please see the README to configure an in-memory only archive.\n")
    ]
  end

  def automatic_setup_text() do
    keyboard_binding_text_color = Config.color(:welcome_keyboard_binding_text, :yellow)
    welcome_body_text_color = Config.color(:welcome_body_text, :white)

    auto_config_perform =
      label do
        text(content: "Press")
        text(content: " y", color: keyboard_binding_text_color, attributes: [:bold])
        text(content: " and then")
        text(content: " enter", color: keyboard_binding_text_color, attributes: [:bold])
        text(content: " to confirm.")
      end

    auto_config_path =
      label do
        text(content: "    config_path", attributes: [:bold])
        text(content: " #{Config.config_path()}")
      end

    auto_config_filename =
      label do
        text(content: "    archive_filename", attributes: [:bold])
        text(content: " #{Config.archive_filename()}")
      end

    [
      label(content: ""),
      label(
        content: "Automatic Setup\n",
        color: welcome_body_text_color,
        attributes: [:underline, :bold]
      ),
      label(content: "To have Historian setup a local archive database, using:\n"),
      auto_config_path,
      auto_config_filename,
      label(content: ""),
      auto_config_perform,
      label(content: "")
    ]
  end

  def manual_setup_text() do
    welcome_body_text_color = Config.color(:welcome_body_text, :white)

    [
      label(content: ""),
      label(
        content: "Manual Setup\n",
        color: welcome_body_text_color,
        attributes: [:underline, :bold]
      ),
      label(content: "Alternatively, you can set the path in your config.exs with:"),
      label(content: ""),
      label do
        text(
          content: "    config ",
          color: welcome_body_text_color,
          attributes: [:bold]
        )

        text(
          content: ":historian, :config_path, \"some/other/path\"\n",
          color: welcome_body_text_color
        )
      end,
      label(content: ""),
      label(content: "and then start historian again."),
      label(content: "")
    ]
  end

  def exit_setup_text() do
    exit_header_color = Config.color(:welcome_header_text, :white)
    keyboard_binding_text_color = Config.color(:welcome_keyboard_binding_text, :yellow)

    [
      label(content: ""),
      label(content: "Exiting\n", color: exit_header_color, attributes: [:underline, :bold]),
      label do
        text(content: "To exit Historian, and return to IEx press")
        text(content: " ctrl+d", color: keyboard_binding_text_color, attributes: [:bold])
      end
    ]
  end

  def logo_text() do
    String.split(@historian_logo, "\n") |> Enum.map(fn line -> label(content: line) end)
  end

  def render(%{screen: :welcome, cursor: cursor, last_event: event}) do
    parts =
      logo_text() ++
        welcome_text() ++ automatic_setup_text() ++ manual_setup_text() ++ exit_setup_text()

    view(bottom_bar: welcome_status_bar(event)) do
      panel height: :fill do
        viewport(offset_y: cursor.cursor) do
          row do
            column(size: 12) do
              parts
            end
          end
        end
      end
    end
  end

  def render(_) do
    nil
  end

  def welcome_status_bar(:install) do
    bg_color = Config.color(:welcome_status_bar_install_background, :yellow)
    color = Config.color(:welcome_status_bar_install_text, :black)

    status_bar_items = [
      navigation_option(gettext("confirm setup"), gettext("enter"), color, bg_color),
      navigation_option(gettext("-- press any other key to cancel"), gettext(""), color, bg_color)
    ]

    status_bar("INSTALL", color, bg_color) do
      status_bar_items
    end
  end

  def welcome_status_bar(_) do
    bg_color = Config.color(:welcome_status_bar_background, :white)
    color = Config.color(:welcome_status_bar_text, :black)

    status_bar_items = [
      navigation_option(gettext("install"), "y", color, bg_color),
      navigation_item(:scroll_down, color, bg_color),
      navigation_item(:scroll_up, color, bg_color),
      navigation_item(:quit, color, bg_color)
    ]

    status_bar("SETUP", color, bg_color) do
      status_bar_items
    end
  end
end
