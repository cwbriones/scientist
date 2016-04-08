defmodule Scientist.Experiment do
  defstruct [
      name: "#{__MODULE__}",
      observables: %{},
      context: %{},
      run_if_fn: nil,
      result: nil
    ]

  def new(name \\ "#{__MODULE__}", opts \\ []) do
    context = Keyword.get(opts, :context, %{})
    %__MODULE__{
      name: name,
      context: context
    }
  end

  # Runs the experiment
  def run(exp = %Scientist.Experiment{observables: %{"control" => control}}) do
    {_, control_result} = eval_observable({"control", control})
    _candidate_results = exp.observables
    |> Map.delete("control")
    |> Map.to_list
    |> Enum.map(&eval_observable/1)

    control_result
  end
  def run(_), do: raise ArgumentError, message: "Experiment must have a control to run"

  defp eval_observable({name, observable}) do
    {name, observable.()}
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

  def set_run_if(exp, run_if_fn) do
    %__MODULE__{exp | run_if_fn: run_if_fn}
  end
end
