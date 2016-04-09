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

  test "it passes through the control" do
    assert :control ==
      Experiment.new
      |> Experiment.add_control(fn -> :control end)
      |> Experiment.run
  end

  test "it runs every candidate" do
    parent = self
    Experiment.new
      |> Experiment.add_control(fn -> send(parent, 1) end)
      |> Experiment.add_observable("one", fn -> send(parent, 2) end)
      |> Experiment.add_observable("two", fn -> send(parent, 3) end)
      |> Experiment.run
    assert_received 1
    assert_received 2
    assert_received 3
  end

  test "it runs the candidates in arbitrary order" do
    parent = self
    experiment = Experiment.new
      |> Experiment.add_control(fn -> send(parent, 1) end)
      |> Experiment.add_observable("one", fn -> send(parent, 2) end)

    Stream.repeatedly(fn -> Experiment.run(experiment) end)
    |> Stream.take(1000)
    |> Enum.to_list
    {_, messages} = Process.info(self, :messages)

    unique = Enum.chunk(messages, 2) |> Enum.uniq |> Enum.count
    assert unique == 2
  end

  test "it compares results" do
    matched = Experiment.new
    |> Experiment.add_control(fn -> 1 end)
    |> Experiment.add_observable("candidate", fn -> 1 end)
    |> Experiment.run(result: true)
    |> Scientist.Result.matched?

    assert matched
  end

  test "it compares with the comparator provided" do
    matched = Experiment.new
    |> Experiment.add_control(fn -> :control end)
    |> Experiment.add_observable("candidate", fn -> "control" end)
    |> Experiment.set_comparator(fn(co, ca) -> Atom.to_string(co) == ca end)
    |> Experiment.run(result: true)
    |> Scientist.Result.matched?

    assert matched
  end

  defmodule RaiseExperiment do
    use Scientist.Experiment

    def enabled?, do: true
    def publish(result) do
      context = result.experiment.context
      send(context.parent, :published)
    end

    def raised(experiment, operation, except) do
      # Send a message with the exception to the parent process
      parent = experiment.context[:parent]
      send(parent, {operation, except})
    end

    def thrown(experiment, operation, except) do
      parent = experiment.context[:parent]
      send(parent, {:thrown, operation, except})
    end
  end

  test "it reports errors raised during compare" do
    experiment = Experiment.new("test", context: %{parent: self})
    |> Experiment.add_control(fn -> :control end)
    |> Experiment.add_observable("candidate", fn -> :control end)

    experiment
    |> Experiment.set_comparator(fn _, _ -> raise "SCARY ERROR" end)
    |> RaiseExperiment.run(result: true)

    assert_received {:compare, %RuntimeError{message: "SCARY ERROR"}}

    experiment
    |> Experiment.set_comparator(fn _, _ -> throw "SCARY ERROR" end)
    |> RaiseExperiment.run(result: true)

    assert_received {:thrown, :compare, "SCARY ERROR"}
  end

  test "it reports errors raised during clean" do
    experiment = RaiseExperiment.new("test", context: %{parent: self})
    |> Experiment.add_control(fn -> :control end)
    |> Experiment.add_observable("candidate", fn -> :control end)

    experiment
    |> Experiment.clean(fn _ -> raise "YOU GOT SPOOKED" end)
    |> RaiseExperiment.run(result: true)

    assert_received {:clean, %RuntimeError{message: "YOU GOT SPOOKED"}}

    experiment
    |> Experiment.clean(fn _ -> throw "YOU GOT SPOOKED" end)
    |> RaiseExperiment.run(result: true)

    assert_received {:thrown, :clean, "YOU GOT SPOOKED"}
  end

  test "it uses the publish function during run" do
    RaiseExperiment.new("test", context: %{parent: self})
    |> Experiment.add_control(fn -> :control end)
    |> Experiment.add_observable("candidate", fn -> :control end)
    |> RaiseExperiment.run(result: true)

    assert_received :published
  end

  defmodule BadPublishExperiment do
    use Scientist.Experiment

    def enabled?, do: true
    def publish(_), do: raise "ka-BOOM"

    def raised(experiment, operation, except) do
      # Send a message with the exception to the parent process
      parent = experiment.context[:parent]
      send(parent, {operation, except})
    end
  end

  test "it reports errors raised during publish" do
    BadPublishExperiment.new("test", context: %{parent: self})
    |> Experiment.add_control(fn -> :control end)
    |> Experiment.add_observable("candidate", fn -> :control end)
    |> BadPublishExperiment.run(result: true)

    assert_received {:publish, %RuntimeError{message: "ka-BOOM"}}
  end
end
