defmodule Historian.MixProject do
  use Mix.Project

  def project do
    [
      app: :historian,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      compilers: [:gettext] ++ Mix.compilers(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
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

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:gettext, "~> 0.17"},
      {:ratatouille, "~> 0.5"},
      {:scribe, "~> 0.10"}
    ]
  end
end
