defmodule Scientist.Experiment do
  defstruct [
      name: "#{__MODULE__}",
      observables: %{},
      context: %{},
      run_if_fn: nil,
      result: nil,
      clean: nil,
      comparator: &(&1 == &2),
      module: Scientist.Default
    ]

  @callback enabled?() :: Boolean
  @callback publish(%Scientist.Result{}) :: any

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)

      def default_context, do: %{}

      def name, do: "#{__MODULE__}"

      def new(name \\ name, opts \\ []) do
        unquote(__MODULE__).new(__MODULE__, name, opts)
      end

      def run(experiment, opts \\ []) do
        unquote(__MODULE__).run(__MODULE__, experiment, opts)
      end

      def raised(_experiment, _operation, except), do: raise except

      def thrown(_experiment, _operation, except), do: throw except

      defoverridable [ default_context: 0, name: 0, raised: 3, thrown: 3 ]
    end
  end

  def new(name \\ "#{__MODULE__}"), do: new(name, [])
  def new(name, opts), do: new(Scientist.Default, name, opts)
  def new(module, name, opts) do
    context = Keyword.get(opts, :context, %{})
    %__MODULE__{
      name: name,
      context: context,
      module: module
    }
  end

  # Runs the experiment
  def run(experiment, opts \\ []), do: run(Scientist.Default, experiment, opts)

  def run(module, exp = %Scientist.Experiment{observables: %{"control" => _}}, opts) do
    observations = exp.observables
    |> Enum.shuffle
    |> Enum.map(&(eval_observable(exp, &1)))
    |> Enum.to_list

    {[control], candidates} = Enum.partition(observations, fn o ->
      o.name == "control"
    end)

    mismatched = Enum.reject(candidates, &observations_match?(module, exp, control, &1))
    result = Scientist.Result.new(exp, control, candidates, mismatched)

    module.publish(result)

    cond do
      Keyword.get(opts, :result, false) -> result
      Scientist.Observation.raised?(control) -> raise control.except
      Scientist.Observation.thrown?(control) -> throw control.except
      true -> control.value
    end
  end
  def run(_, _, _), do: raise ArgumentError, message: "Experiment must have a control to run"

  defp eval_observable(experiment, {name, observable}) do
    Scientist.Observation.new(experiment, name, observable)
  end

  defp observations_match?(module, experiment, control, candidate) do
    try do
      Scientist.Observation.equivalent?(control, candidate, experiment.comparator)
    rescue
      except ->
        module.raised(experiment, :compare, except)
        false
    catch
      except ->
        module.thrown(experiment, :compare, except)
        false
    end
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
