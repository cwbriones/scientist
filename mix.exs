defmodule Scientist.Mixfile do
  use Mix.Project

  def project do
    [app: :scientist,
     version: "0.2.0",
     elixir: "~> 1.2",
     deps: deps,
     package: package,
     name: "Scientist",
     source_url: "https://github.com/cwbriones/scientist",
     description: """
     A library for carefully refactoring critical paths in your elixir application.
     """] ++ test
  end

  defp test do
    [test_coverage: [tool: ExCoveralls],
     preferred_cli_env: [coveralls: :test]]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.18.0", only: :dev},
      {:earmark, "~> 1.3", only: :dev},
      {:excoveralls, "~> 0.4", only: :test}
    ]
  end

  defp package do
    [maintainers: ["Christian Briones"],
     licenses: ["MIT"],
     links: %{github: "https://github.com/cwbriones/scientist"},
     files: ~w(lib LICENSE mix.exs README.md)]
  end
end
