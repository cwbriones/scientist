defmodule Scientist.Default do
  use Scientist.Experiment

  def enabled?, do: true
  def publish(_), do: :ok
end
