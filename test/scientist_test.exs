defmodule TestExperiment do
  use Scientist.Experiment

  def default_context, do: %{parent: self}

  def enabled?, do: true

  def raised(experiment, operation, except) do
    %{parent: p} = experiment.context
    send(p, {:raised, operation, except})
  end

  def publish(result) do
    %{parent: p} = result.experiment.context
    send(p, {:publish, result})
  end
end

defmodule ScientistTest do
  use ExUnit.Case

  use Scientist, experiment: TestExperiment

  test "science creates an experiment" do
    exp =
      science "my experiment", run: false do
      end

    assert match?(%Scientist.Experiment{}, exp)
  end

  test "science runs the experiment when the block ends" do
    value =
      science "my experiment" do
        control(do: 1)
        candidate(do: 1)
      end

    assert value == 1
    assert_received {:publish, %Scientist.Result{}}
  end

  test "science uses the control and candidate blocks" do
    science "my experiment" do
      control(do: 1)
      candidate(do: 1)
      candidate("second", do: 2)
    end

    assert_received {:publish, result}
    refute Scientist.Result.matched?(result)

    assert result.control.value == 1

    candidate_values =
      result.candidates
      |> Enum.map(fn c -> c.value end)
      |> Enum.sort()

    assert candidate_values == [1, 2]
  end

  test "science uses the ignore block" do
    science "my experiment" do
      control(do: true)
      candidate(do: false)

      ignore do
        send(self, :ignore_one)
        false
      end

      ignore(control, candidate) do
        control and !candidate
      end
    end

    assert_received :ignore_one
    assert_received {:publish, result}
    assert Scientist.Result.ignored?(result)
  end

  test "science uses the compare block" do
    science "my experiment" do
      control(do: 1)
      candidate(do: 2)

      compare(x, y, do: x + 1 == y)
    end

    assert_received {:publish, result}
    assert Scientist.Result.matched?(result)
  end

  test "science uses the clean block" do
    science "my experiment" do
      control(do: %{a: 1, b: 2})
      candidate(do: %{a: 1, c: 2})

      clean(x, do: x[:a])
    end

    assert_received {:publish, result}
    assert result.control.value == %{a: 1, b: 2}
    assert result.control.cleaned_value == 1
  end

  test "science uses the run_if block" do
    science "my experiment" do
      control(do: 1)
      candidate(do: 1)
      run_if(do: false)
    end

    refute_received {:publish, _}
  end

  test "science uses the before_run block" do
    parent = self

    science "my experiment" do
      control(do: 1)
      candidate(do: 1)
      before_run(do: send(parent, :before_run))
    end

    assert_received {:publish, _}
    assert_received :before_run
  end
end
