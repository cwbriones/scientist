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
end
