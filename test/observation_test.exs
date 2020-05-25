defmodule ObservationTest do
  use ExUnit.Case

  alias Scientist.Experiment
  alias Scientist.Observation

  test "it runs and records execution" do
    candidate = fn ->
      :timer.sleep(100)
      :control
    end

    experiment = Experiment.new("test")
    observation = Observation.new(experiment, "control", candidate)
    assert_in_delta 100, observation.duration, 10
  end

  test "it swallows exceptions" do
    candidate = fn -> raise "foo" end
    experiment = Experiment.new("test")
    observation = Observation.new(experiment, "control", candidate)

    assert Observation.raised?(observation)
    assert Observation.except?(observation)
  end

  test "it swallows throws" do
    candidate = fn -> throw("foo") end
    experiment = Experiment.new("test")
    observation = Observation.new(experiment, "control", candidate)

    assert Observation.thrown?(observation)
    assert Observation.except?(observation)
  end

  test "it compares values" do
    experiment = Experiment.new("test")
    control = Observation.new(experiment, "control", fn -> 4 - 1 end)
    candidate = Observation.new(experiment, "control", fn -> 1 + 2 end)

    assert Observation.equivalent?(control, candidate)
  end

  test "it compares values with a function" do
    experiment = Experiment.new("test")
    control = Observation.new(experiment, "control", fn -> :control end)
    candidate = Observation.new(experiment, "control", fn -> "control" end)

    compare = fn x, y -> Atom.to_string(x) == y end

    assert Observation.equivalent?(control, candidate, compare)
  end

  test "it compares types of exceptions" do
    experiment = Experiment.new("test")
    control = Observation.new(experiment, "control", fn -> raise "foo" end)
    candidate = Observation.new(experiment, "control", fn -> raise ArgumentError end)

    refute Observation.equivalent?(control, candidate)
  end

  test "it compares exception messages" do
    experiment = Experiment.new("test")

    control =
      Observation.new(experiment, "control", fn ->
        raise ArgumentError, message: "foo"
      end)

    candidate =
      Observation.new(experiment, "control", fn ->
        raise ArgumentError, message: "bar"
      end)

    refute Observation.equivalent?(control, candidate)
  end

  test "the cleaned value is the same as the value by default" do
    observation =
      Experiment.new("test")
      |> Observation.new("control", fn -> :control end)

    assert observation.value == observation.cleaned_value
  end

  test "it uses the clean function from the experiment when available" do
    observation =
      Experiment.new("test")
      |> Experiment.clean_with(&Atom.to_string/1)
      |> Observation.new("control", fn -> :control end)

    assert observation.value == :control
    assert observation.cleaned_value == "control"
  end
end
