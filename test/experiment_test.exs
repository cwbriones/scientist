defmodule ExperimentTest do
  use ExUnit.Case

  alias Scientist.Experiment

  test "it has a default name" do
    assert Experiment.new.name == "Elixir.Scientist.Experiment"
  end

  test "it accepts a context" do
    experiment = Experiment.new("Some experiment", context: %{foo: "bar"})
    assert experiment.context == %{foo: "bar"}
  end

  test "it can't be run without a control" do
    experiment = Experiment.new
    assert_raise(ArgumentError, fn -> Experiment.run(experiment) end)
  end

  test "it only can have a single control" do
    fun = fn ->
      Experiment.new
      |> Experiment.add_control(fn -> :control end)
      |> Experiment.add_control(fn -> :second_control end)
    end
    assert_raise(ArgumentError, fun)
  end
end
