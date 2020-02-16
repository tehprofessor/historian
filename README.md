# Historian

```text
██╗  ██╗██╗███████╗████████╗ ██████╗ ██████╗ ██╗ █████╗ ███╗   ██╗
██║  ██║██║██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗██║██╔══██╗████╗  ██║
███████║██║███████╗   ██║   ██║   ██║██████╔╝██║███████║██╔██╗ ██║
██╔══██║██║╚════██║   ██║   ██║   ██║██╔══██╗██║██╔══██║██║╚██╗██║
██║  ██║██║███████║   ██║   ╚██████╔╝██║  ██║██║██║  ██║██║ ╚████║
╚═╝  ╚═╝╚═╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝


An interactive history manager and snippet archival tool for IEx.
```

## Table of Contents

- [Features](#features)
- [Installation & Setup](#installation--setup)
- [License](#license)

## Features

- [View History](#view-history)
    - [Paging](#paging)
    - [Filtering](#filtering)
- [Archiving](#archive)
    - [Creating an Entry](#creating-an-entry)
    - [Using an Entry](#using-an-entry)
- [Termianl UI](#terminal-ui)
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
_page_buffer_pid = Historian.pages()
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

```
iex> pager = Historian.pages(100)
iex> Historian.tui!(pager)
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

Historian need to be added as a dependency or installed as an archive.

### Installation


#### Project Dependency

**BELOW IS NOTHING BUT LIES IT HAS NOT BEEN PUBLISHED JUST YET, ADD DEP USING GIT OR CHECKOUT LOCALLY**

`Historian` is [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `historian` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:historian, "~> 0.11.1", only: :dev}
  ]
end
```

### Manual Setup

If you try to run this right now it'll probably complain about the path for the historian archive db.

`mkdir -p ~/.config/historian`

I'll get that ironed out (soon).

[add screenshot]


## License

Copyright 2020 Tehprofessor

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
