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

_Work Log:_

**Feb. 10, 2020** -- Major quality improvements to Historian module (it was mostly outdated as the internals changed), documentation still needs an update, still need to wire up setup action in the TUI.
**Feb. 09, 2020** -- Welcome Screen added though setup isn't firing because it's not wired up yet (I just realized as I'm writing this...) Added some tests. Still need to clean up code and add gifs once setup is being called, but pretty close.
**Feb. 08, 2020** -- Initial commit, a couple things missing (making setup easier, add archive entries through terminal UI, some commands need to be updated, add gifs here, and... I should add tests -_-;). I should have that finished by tomorrow afternoon.

### Setup

If you try to run this right now it'll probably complain about the path for the historian archive db.

`mkdir -p ~/.config/historian`

I'll get that ironed out (soon).

[add screenshot]

## Features

- [View History](#View History)
- [Archiving](#Archiving)
- [Termianl UI](#Terminal UI)

### View History

Lamest by itself feature ever, ha... and WRITE THIS DOCUMENTATION.

#### Paging

#### Filtering

### Archiving

A unique feature of Historian is the "archive of snipppets," i.e. the ability to save line(s), or your clipboard to an
shortcut/alias/name.

You can interact with Historian using the `Historian` module as outlined below or by using the TUI provided by calling `Historian.view_history/2`.

#### Creating an Entry

Creating an entry with a string:
```elixir
Historian.archive_entry!(:special_query, "query = from(...)")
```

from your clipboard contents:
```elixir
Historian.archive_from_clipboard!(:special_query)
```

or from the history buffer:

```elixir
Historian.archive_from_history!(:special_query, :pluck, [1,2,13,17,18,33])
```

#### Using an Entry

You can then copy the entry to your clipboard with:

```elixir
Historian.copy(:special_query)
```

eval it directly:

```elixir
Historian.eval_entry(:special_query)
```

or even throw it into an anonymous function `fn/0`:

```elixir
my_fun = Historian.entry_to_fun(:special_query)
```

### Terminal UI

In an `iex` session after installing historian, and start the historian ui with:
```
iex> Historian.view_history()
```

As you read through the TUI features list, you'll notice next to the header for that entry there are braces containing a character; that's the key to press for that section. There may be more options within each sections details, but I've put them there to make skimming this faster.

#### Interactive History `[1]`

Or alternatively specifying the page size and offset:
```
iex> lines = 100
iex> offset = 100
# Default is 100 lines, with an offset of 0 (the most recent)
iex> Historian.view_history(lines, offset)
```

#### Exiting Historian `[ctrl+d]`

To leave the historian interface and return to your `iex` prompt just press `ctrl+d` at anytime in the historian UI.

#### Navigating Pages `[j]` / `[k]`

You can view your history and scroll (`j` down/ `k` up) through entries, pressing `y` to copy the current line, `spacebar` to select multiple lines.

#### Searching `[s]`

When viewing your history you can press `s` and Historian will filter matches highlighting the matching portion.

#### Interactive Archive `[2]`

To view all archived materials using interactive mode, press `2` at anytime (except when searching). You can navigate, select, and copy them using the same `j`, `k`, and `y` commands as when viewing the history.

[add screenshot]

**note:** To return to the history screen, press `1`

There is an additional `Y` command which will join multiple lines using a space and a backslash:

```elixir
IO.inspect("contrived_example") \
|> IO.inspect(label: "using new lines")
```

## Installation

`Historian` is [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `historian` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:historian, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/historian](https://hexdocs.pm/historian).

## License

Copyright 2020 Tehprofessor

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
