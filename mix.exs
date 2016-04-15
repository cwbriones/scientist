defmodule Scientist.Mixfile do
  use Mix.Project

  def project do
    [app: :scientist,
     version: "0.1.0",
     elixir: "~> 1.2",
     deps: deps,
     package: package,
     name: "Scientist",
     source_url: "https://github.com/cwbriones/scientist",
     description: """
     An elixir library for refactoring critical paths in your application.
     """]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps, do: []

  defp package do
    [maintainers: ["Christian Briones"],
     licenses: ["MIT"],
     links: %{github: "https://github.com/cwbriones/scientist"},
     files: ~w(lib LICENSE mix.exs README.md)]
  end
end
