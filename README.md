# Historian

```text
██╗  ██╗██╗███████╗████████╗ ██████╗ ██████╗ ██╗ █████╗ ███╗   ██╗
██║  ██║██║██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗██║██╔══██╗████╗  ██║
███████║██║███████╗   ██║   ██║   ██║██████╔╝██║███████║██╔██╗ ██║
██╔══██║██║╚════██║   ██║   ██║   ██║██╔══██╗██║██╔══██║██║╚██╗██║
██║  ██║██║███████║   ██║   ╚██████╔╝██║  ██║██║██║  ██║██║ ╚████║
╚═╝  ╚═╝╚═╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝
[beta]

An interactive history manager and snippet archival tool for IEx.
```

Historian is a developer tool to make interacting with your IEx history easier by providing text and/or graphical (TUI) utilities to search, page through, copy and paste, and even save specific line(s) or snippets to a persistent archive [_db_].

Historian comes with two modes an inline "text mode" which you can interact with by calling `Historian` directly, or a "Terminal User Interface" (TUI) which provides a graphical interface for using Historian. Please see the [features](#features) section for a walkthrough of each.

It's completely non-destructive to your history so give it a try, in fact, all it really does is make `:group_history` more pleasant to work with. 

[_db_]: It's an ETS table persisted to disk, please see [installation and setup](#installation--setup) for more details.

## Status

Historian is in **beta**, and may have bugs, or usability issues on some platforms or configurations. It is a developer tool, intended to only be used in `:dev` so the risk of any harm is low.

MacOS, Linux, and Windows are all supported but Linux and Windows have had the least amount of testing as of February 16, 2020. I will update this once on those platforms (under various configurations) is verified correct.

### Bugs and Problems

If you're feeling generous with your time, please create an issue with the details (including operating system, terminal application, and locale) and I will get it fixed up for you. Screenshots or gifs of issues are also tremendously helpful and appreciated.

I am on Twitter and the Elixir slack under the same handle.

## Table of Contents

- [Features](#features)
- [Installation & Setup](#installation--setup)
- [Configuration](#configuration)
- [Roadmap](#roadmap--planned-features)
- [Acknowledgements](#acknowledgements)
- [License](#license)

## Features

- [View History](#view-history)
    - [Paging](#paging)
    - [Filtering](#filtering)
- [Archiving](#archive)
    - [Creating an Entry](#creating-an-entry)
    - [Using an Entry](#using-an-entry)
- [Terminal UI](#terminal-ui)
    - [History `[1]`](#history-1)
    - [Exiting Historian `[ctrl+d]`](#exiting-historian-ctrld)
    - [Navigating Lines `[j]` / `[k]`](#navigating-lines-j--k)
    - [Searching `[s]`](#searching-s)
    - [Viewing Your Archive `[2]`](#viewing-your-archive-2)
    - [Editing An Archive Item `[e]`](#editing-an-archive-item-e)
    - [New Archive Item `[n]`](#new-archive-item-n)

### View History

View a specific line of history with `line = 0` being the most recent line in your history:

```elixir
iex> Historian.line(0)
"Historian.line(0)"
```

to view the last (oldest) line of your history you can set `line = :infinity`:

```elixir
iex> Historian.line(:infinity)
"IO.puts(\"is this magic?\")"
```

View the 100 most recent lines of your history:

```elixir
# We'll cover the pid in the section below
iex> _page_buffer_pid = Historian.pages()
```

#### Paging

Because the history is constantly changing, you can freeze it at a point in time, by reusing the `Historian.PageBuffer` pid that is returned from calling `pages/1`.

*Note:* Page indexes start from `0` not `1`.

```elixir
iex> page_size = 10
# Creating a pager, takes an (in-memory) snapshot of your history, giving you an easier and more sane way to page
# through it; since, each new line will no longer affect the offset.
iex> pager = Historian.pages(page_size)
#> Viewing page  0:
#> +---------------------------------------------------+
#> |  id  |  value                                     |
#> +---------------------------------------------------+
#> |   0  |  Historian.pages(10)                       |
#> |   1  |  Historian.view_history                    |
#> |   2  |  Historian.Clipboard.paste()               |
#> |   3  |  Historian.view_history                    |
#> |   4  |  Application.get_env(:historian, :colors)  |
#> |   5  |  Historian.view_history                    |
#> |   6  |  Application.get_env(:historian, :colors)  |
#> |   7  |  Map.get(%{}, :shites)                     |
#> |   8  |  Historian.view_history                    |
#> |   9  |  r Historian.TUi.Elements                  |
#> +---------------------------------------------------+
# Display the first page (100 most recent lines) of history
iex> _pager = Historian.page(pager, 0)
```

`Historian.next_page/1` and `Historian.prev_page/1` move the page buffer `+1/-1` page at a time, each time updating the buffer's
current page.

```elixir
iex> page_size = 100
iex> pager = Historian.pages(page_size)
# Moves the buffer to the second page (index = 1)
iex> Historian.next_page(pager)
# Moves the buffer back to the first page (index = 0)
iex> Historian.prev_page(pager)
```

`Historian.page/2` view a specific page in the buffer, without altering the current page:

```elixir
iex> page_size = 100
iex> pager = Historian.pages(page_size)
# Assuming you have at least 28 pages of history (page numbers start from 0).
iex> _ = Historian.page(pager, 27)
```

`Historian.page!/2` view a specific page in the buffer AND update the current page in the buffer:

```elixir
iex> page_size = 100
iex> pager = Historian.pages(page_size)
# Assuming you have at least 28 pages of history (page numbers start from 0).
iex> _ = Historian.page(pager, 27)
```

#### Filtering

Historian provides a few simple ways to filter and view your history.

`Historian.search/2` allow you can search through the current page of history, printing a table of the matching results with the search term highlighted.

```elixir
iex> _ = Historian.search(pager, "Historian.")
```

`Historian.search/1` will use an existing buffer (most recently created), or if there are no existing page buffers create a new one.

```elixir
iex> _ = Historian.search("Historian.")
```

### Archive

A unique feature of Historian is the "archive of snipppets," i.e. the ability to save line(s), or your clipboard to an
shortcut/alias/name.

You can view your entire archive as a text formatted table with:

```elixir
iex> Historian.print_archive()
```

You can interact with Historian using the `Historian` module as outlined below or by using the TUI provided by calling `Historian.view_history/2`.

#### Creating an Entry

Creating an entry with a string:
```elixir
iex> Historian.archive_entry!(:special_query, "query = from(...)")
"query = from(...)"
```

from the clipboard contents:
```elixir
iex> Historian.archive_from_clipboard!(:special_query)
"query = from(...)"
```

or from the history buffer:

```elixir
iex> Historian.archive_from_history!(:wow_multiple_lines, :pluck, [1, 2, 33])
"IO.inspect(:yolo)\nIO.inspect(:womp)\nIO.inspect(:nomp)"
```

#### Using an Entry

You can then copy the entry to your clipboard with:

```elixir
iex> Historian.copy(:special_query)
{:ok, :copied_to_clipboard}
```

eval it directly:

```elixir
iex> Historian.eval_entry(:special_query)
%Special.Result{magical: :yes}
```

or even throw it into an anonymous function `fn/0`:

```elixir
iex> my_fun = Historian.entry_to_fun(:special_query)
iex> my_fun.()
%Special.Result{magical: :yes}
```

You can also use `Historian.Clipboard.paste/0` to get your clipboard as a two-item tuple:

```elixir
iex> Historian.Clipboard.paste()
{:ok, "wow this is from my clipboard, cool, fresh..."}
```

### Terminal UI

In an `iex` session start the historian TUI with:

```elixir
iex> Historian.tui!()
```

Without providing any arguments, the UI defaults to showing the 100 most recent entries of your history. Passing in
a `PageBuffer` process will open the UI to the buffer's current page.

```elixir
iex> pager = Historian.pages(100)
iex> Historian.tui!(pager)
# An alias for tui! is view_history
iex> Historian.view_history()
```

As you read through the TUI features list, you'll notice next to the header for that entry there are braces containing a character(s); that's the key to press for that section. There may be more options within each sections details, but I've put them there to make skimming this faster.

#### History `[1]`

You can pass in a specific page number to view by using `Historian.view_page/2`:

```elixir
iex> pager = Historian.pages(100)
iex> page_ten = 10
# View page ten of the page buffer
iex> Historian.view_page(pager, page_ten)
```

`Historian.view_page/1` views the current page in the TUI:

```elixir
iex> pager = Historian.pages(100)
# Set the current page in the buffer to 111`
iex> _ = Historian.page(pager, 11)
# Opens the UI to page 11
iex> Historian.view_page(page)
```

#### Exiting Historian `[ctrl+d]`

To leave the historian interface and return to your `iex` prompt just press `ctrl+d` at anytime in the historian UI.

#### Navigating Lines `[j]` / `[k]`

You can view your history and scroll (`j` down/ `k` up) through entries, pressing `y` to copy the current line, `spacebar` to select multiple lines. Right now you cannot switch pages in the TUI, you gotta exit it first and change the page, this
will be remedied in a future release.

#### Searching `[s]`

When viewing your history you can press `s` and Historian will filter entries on the page highlighting the matching portion,
press `enter` to move up `k` and down `j` through entries and `y` to copy the selected line. Press `e` to refine your
search.

#### Viewing Your Archive `[2]`

To view all archived materials using interactive mode, press `2` at anytime (except when searching, will be improved in a future release). You can navigate, select, and copy entries using the same `j`, `k`, and `y` commands as when viewing the history.

To open the Historian TUI directly to your archive from IEx:

```elixir
iex> Historian.view_archive()
```

**note:** To return to the history screen, press `1`

There is an additional `Y` command which will join multiple lines in an entry using a space and a backslash, example
output from using `Y` with these three lines selected:

```elixir
Something.create(%{coffee: :is_delicious})
|> A.ReallyLong.And.Obtuse.Name.I.Would.Like.perform_magics()
|> IO.inspect(label: "i am terrible at naming things")
```

you would then have on your clipboard:

```elixir
Thinger.create(%{}) \
|> A.ReallyLong.And.Obtuse.Name.I.Would.Like.perform_something() \
|> IO.inspect(label: "i am terrible at naming things")
```

#### Editing an Archive Item `[e]`

Select an archive item and press `e` to edit the name and content. Please note the TUI assumes all names are atoms AND
anything you write in there _will_ be turned into an atom[^1]. You can navigate the fields using the up `↑` and down `↓` arrows, once done, select either `cancel` or `save` and press `enter`.

#### New Archive Item `[n]`

Select an archive item and press `n` to create a new item. Please note the TUI assumes all names are atoms AND
anything you write in there _will_ be turned into an atom[^1]. You can navigate the fields using the up `↑` and down `↓` arrows, once done, select either `cancel` or `save` and press `enter`.

[^1]: If this is actually a problem for anyone, file an issue, and I'll make it configurable.

## Installation & Setup

Historian need to be added as a dependency, and setup can be performed by running `Historian.tui!/0` from an `IEx` session.

### Installation

`Historian` is [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `historian` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:historian, "~> 0.11.0-beta", only: :dev}
  ]
end
```

To see the most current version available in Hex use: `mix hex.info historian`

### Automatic Setup

Historian will launch a welcome screen the first time you use the Terminal UI, the easiest way is:

```elixir
iex> Historian.tui!()
```

It will detail the installation path and filename, to install press `y` and `enter` to confirm.

### Manual Setup

If you'd prefer to manually setup Historian, here are the steps (which by the way show the defaults):

1. Make a directory to store the archive ets file.

```shell script
mkdir -p ~/.config/historian
```

2. Configure the `config_path` to be the directory you made in step 1

```elixir
config :historian, :config_path, Path.join([System.user_home(), ".config", "historian"])
```

## Configuration

Below are all the configuration options (and their defaults) available in Historian:

```elixir
# This is the path historian will use to persist the Archive's ets table.
config :historian, :config_path, Path.join([System.user_home(), ".config", "historian"])

# This is the filename for the Historian ets table.
config :historian, :archive_filename, "historian-db.ets"

# The name of the archive's `ets` table, no reason to change this unless you
# have a conflicting ets table (wow, what are the odds?).
config :historian, :archive_table_name, :historian_archive_db

# `nil` means unset and will be considered `true` at runtime, if you do not
# want to persist the archive to disk you must set this to `false`.
config :historian, :persist_archive, nil

# The default is probably not usable on light-background terminals, sorry! But,
# you can select one of the `_light` alternatives listed directly below which 
# will work. If these are all terrible for your setup, please make a PR with
# the details and I'll get something made for you... or see the DIY colors
# section below.
config :historian,
       :color_scheme,
       :default
#       :high_contrast_dark
#       :high_contrast_light # For use on light-background terminals
#       :black_and_white_dark
#       :black_and_white_light # For use on light-background terminals

# DIY Color Scheme #
#
# A map of colors used by Historian. The primary purpose of this setting is for 
# mainly for accessibility, I don't want someone to have a shitty experience because
# I was an asshole and chose colors that are hard/impossible for them to read.
config :historian, :colors, %{
                                archive_item_current_line_background: :black,
                                archive_item_current_line_text: :white,
                                archive_panel_background: :black,
                                archive_panel_title_text: :cyan,
                                archive_status_bar_background: :green,
                                archive_status_bar_text: :black,
                                dialog_box_cancel_text: :red,
                                dialog_box_confirm_text: :blue,
                                dialog_box_content_text: :yellow,
                                dialog_box_label_background: :white,
                                dialog_box_label_background_selected: :yellow,
                                dialog_box_label_content_text: :yellow,
                                dialog_box_label_text: :black,
                                dialog_box_label_text_selected: :black,
                                dialog_box_panel_background: :white,
                                dialog_box_panel_text: :black,
                                history_current_line_background: :black,
                                history_current_line_text: :white,
                                history_line_background: :default,
                                history_line_copied_line_background: :default,
                                history_line_copied_line_ok: :yellow,
                                history_line_multiselect_background_selected: :black,
                                history_line_multiselect_text_selected: :blue,
                                history_line_text: :white,
                                history_split_view_panel_background: :black,
                                history_split_view_panel_title_text: :cyan,
                                history_status_bar_background: :magenta,
                                history_status_bar_text: :white,
                                screen_navigation_app_name_background: :cyan,
                                screen_navigation_app_name_text: :black,
                                screen_navigation_background: :black,
                                screen_navigation_text: :white,
                                screen_navigation_text_selected: :cyan,
                                search_item_matching_text: :cyan,
                                search_item_matching_text_selected: :cyan,
                                search_status_bar_background: :yellow,
                                search_status_bar_text: :black
                              }
```

## Roadmap & Planned Features

Below is the roadmap to release, starting from the first public release (`beta-2`). You may notice testing and documentation listed under "features" that's because I view them as features.

### Beta 3 (completed Feb. 22, 2020)

#### Fixes

- [x] TUI: Support for light-background terminals with `config :historian, :color_scheme, :black_and_white_light`
- [x] TUI: Screen navigation working after search
- [x] TUI: Fixed crash when attempting to navigate no matching search results
- [x] TUI: Search results now scroll properly

#### Features

- [x] TUI: Black and white mode for light and dark terminals
- [x] TUI: High contrast mode for light and dark terminals
- [x] TUI: Hide the search (and view history) by pressing `s` while navigating results
- [x] Delete an item from your archive by name with `Historian.delete_entry/1`
- [x] Open the TUI directly to your archive `Historian.view_archive/0`
- [x] Basic CI using Travis (I need to setup a matrix to test copy/paste on different OSes, finalize how I want to test for visual regressions, and support other elixir/otp versions)

### Beta 4


#### Fixes

- [ ] Improve terrible names of modules and functions (more so internally but public API could use some love)

#### Features

- [ ] Complete documentation in `@moduledoc` so using `h Historian` in IEx is useful
- [ ] User configurable keyboard bindings
- [ ] TUI: Help screen
- [ ] Change page of the buffer from the TUI
- [ ] More consistent UI making sure colors, text decorations, copy (verbiage), etc are consistent and coherent

### Beta 5

- [ ] Search your archive
- [ ] Make the `Welcome` TUI screen use `Gettext`
- [ ] OS specific CI coverage of copy/paste
- [ ] Improve editing an archive entry experience (even if it's marginally so, as I'm 100% _not_ trying to pack a text editor in this bad-mama-jamma)

### TBD

The following may not make it to the first official non-beta release, and may be included in future versions:

- [ ] Mix tasks for using Historian without entering IEx
- [ ] Mix tasks for: exporting, viewing, and backing up both your archive and history
- [ ] Localization, `Gettext` is in use almost everywhere (probably not used well, but it's my first rodeo with it) except the welcome screen; unfortunately though, I only know English... contributors wanted for localization! :)
- [ ] TUI regression testing
- [ ] History and archive statistics

## Acknowledgements

Terminal UI powered by [ExTermbox](https://github.com/ndreynolds/ex_termbox) and [Ratatouille](https://github.com/ndreynolds/ratatouille)

## License

Copyright 2020 Tehprofessor

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
