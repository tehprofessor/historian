defmodule Historian.MixProject do
  use Mix.Project

  @version "0.11.0-beta.3"

  def project do
    [
      app: :historian,
      version: @version,
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      compilers: [:gettext] ++ Mix.compilers(),
      source_url: "https://github.com/tehprofessor/historian",
      description: description(),
      deps: deps(),
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore.exs",
        plt_add_deps: :transitive,
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ],
      package: package(),
      docs: [
        main: "readme",
        extras: [
          "README.md"
        ],
        source_ref: "v#{@version}",
        source_url: "https://github.com/tehprofessor/historian",
        markdown_processor: ExDoc.Markdown.Earmark
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      env: [
        archive_filename: "historian-db.ets",
        archive_table_name: :historian_archive_db
      ],
      mod: {Historian.Application, []}
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 1.0-pre", only: :dev, runtime: false},
      {:earmark, "~> 1.4", only: :dev},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:gettext, "~> 0.17"},
      {:ratatouille, "~> 0.5"}
    ]
  end

  def description do
    "Historian is a developer tool to make interacting with your IEx history easier by providing text and/or graphical (TUI) utilities to search, page through, copy and paste, and even save specific line(s) or snippets to a persistent archive."
  end

  defp package do
    [
      app: "historian",
      files: ~w(lib README.MD mix.exs .formatter.exs),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/tehprofessor/historian"},
      name: "historian"
    ]
  end
end
