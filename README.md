# Scientist

A library for monitoring refactored code.

This is an elixir clone of the ruby gem [scientist](https://github.com/github/scientist).

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add scientist to your list of dependencies in `mix.exs`:

        def deps do
          [{:scientist, "~> 0.0.1"}]
        end

  2. Ensure scientist is started before your application:

        def application do
          [applications: [:scientist]]
        end

