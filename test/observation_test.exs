defmodule ObservationTest do
  use ExUnit.Case

  alias Scientist.Experiment
  alias Scientist.Observation

  test "it runs and records execution" do
    observable = fn ->
      :timer.sleep(100)
      :control
    end
    experiment = Experiment.new("test")
    observation = Observation.new(experiment, "control", observable)
    assert_in_delta 100, observation.duration, 10
  end

  test "it swallows exceptions" do
    observable = fn -> raise "foo" end
    experiment = Experiment.new("test")
    observation = Observation.new(experiment, "control", observable)

    assert Observation.raised?(observation)
    assert Observation.except?(observation)
  end

  test "it swallows throws" do
    observable = fn -> throw "foo" end
    experiment = Experiment.new("test")
    observation = Observation.new(experiment, "control", observable)

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
    control = Observation.new(experiment, "control", fn ->
      raise ArgumentError, message: "foo"
    end)
    candidate = Observation.new(experiment, "control", fn ->
      raise ArgumentError, message: "bar"
    end)

    refute Observation.equivalent?(control, candidate)
  end
end
