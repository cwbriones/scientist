defmodule Scientist.Experiment do
  defstruct [
      name: "#{__MODULE__}",
      observables: %{},
      context: %{},
      run_if_fn: nil,
      result: nil,
      clean: nil,
      comparator: &(&1 == &2)
    ]

  def new(name \\ "#{__MODULE__}", opts \\ []) do
    context = Keyword.get(opts, :context, %{})
    %__MODULE__{
      name: name,
      context: context
    }
  end

  def run(experiment), do: run(experiment, [])

  # Runs the experiment
  def run(exp = %Scientist.Experiment{observables: %{"control" => _}}, opts) do
    observations = exp.observables
    |> Enum.shuffle
    |> Enum.map(&(eval_observable(exp, &1)))
    |> Enum.to_list

    {[control], candidates} = Enum.partition(observations, fn o ->
      o.name == "control"
    end)

    if Scientist.Observation.raised?(control) do
      raise control.exception
    end
    result = Scientist.Result.new(exp, control, candidates)
    if Keyword.get(opts, :result, false) do
      result
    else
      control.value
    end
  end
  def run(_, _), do: raise ArgumentError, message: "Experiment must have a control to run"

  defp eval_observable(experiment, {name, observable}) do
    Scientist.Observation.new(experiment, name, observable)
  end

  # Adds the given observable to the experiment as a control
  def add_control(%Scientist.Experiment{observables: %{"control" => _}}, _) do
    raise ArgumentError, message: "Experiment can only have a single control"
  end
  def add_control(exp, observable), do: add_observable(exp, "control", observable)

  def add_observable(exp, name, observable) do
    new_observables = exp.observables |> Map.put(name, observable)
    %__MODULE__{exp | observables: new_observables}
  end

  def set_comparator(exp, compare) do
    %__MODULE__{exp | comparator: compare}
  end

  def clean(exp, cleaner) do
    %__MODULE__{exp | clean: cleaner}
  end

  def set_run_if(exp, run_if_fn) do
    %__MODULE__{exp | run_if_fn: run_if_fn}
  end
end
