defmodule Historian.MixProject do
  use Mix.Project

  def project do
    [
      app: :historian,
      version: "0.11.1",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      compilers: [:gettext] ++ Mix.compilers(),
      source_url: "https://github.com/tehprofessor/historian",
      deps: deps(),
      docs: [
        main: "README",
        extras: [
          "README.md"
        ]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      env: [
        history_server: Historian.HistoryServer,
        entry_server: Historian.EntryServer,
        historian_path: "~/.config/historian"
      ],
      mod: {Historian.Application, []}
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:gettext, "~> 0.17"},
      {:ratatouille, "~> 0.5"},
      {:scribe, "~> 0.10"}
    ]
  end
end
