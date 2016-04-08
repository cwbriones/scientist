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
    exp.observables["control"].()

    exp.result
  end
  def run(_), do: raise ArgumentError, message: "Experiment must have a control to run"

  # Adds the given observable to the experiment as a control
  def add_control(%Scientist.Experiment{observables: %{"control" => _}}, _) do
    raise ArgumentError
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
