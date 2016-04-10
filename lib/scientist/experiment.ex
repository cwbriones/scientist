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

      def raised(_experiment, _operation, except), do: raise except

      def thrown(_experiment, _operation, except), do: throw except

      defoverridable [ default_context: 0, name: 0, raised: 3, thrown: 3 ]
    end
  end

  @doc """
  Creates an experiment with the given name and context, using Scientist.Default as a
  callback module when none is provided.
  """
  def new(name \\ "#{__MODULE__}"), do: new(name, [])
  def new(name, opts), do: new(Scientist.Default, name, opts)
  def new(module, name, opts) do context = Keyword.get(opts, :context, %{})
    %__MODULE__{
      name: name,
      context: context,
      module: module
    }
  end

  @doc """
  Executes the given block, calling thrown and raised with the given reason if the block
  throws or raises an exception.
  """
  defmacro guarded(exp, operation, do: block) do
    quote do
      try do
        unquote(block)
      catch
        except ->
          unquote(exp).module.thrown(unquote(exp), unquote(operation), except)
          nil
      rescue
        except ->
          unquote(exp).module.raised(unquote(exp), unquote(operation), except)
          nil
      end
    end
  end

  @doc """
  Runs the experiment, using Scientist.Default as a callback module if none is provided.
  """
  def run(exp, opts \\ [])
  def run(exp = %Scientist.Experiment{observables: %{"control" => c}}, opts) do
    if should_run?(exp) do
      observations = exp.observables
      |> Enum.shuffle
      |> Enum.map(&(eval_observable(exp, &1)))
      |> Enum.to_list

      {[control], candidates} = Enum.partition(observations, fn o ->
        o.name == "control"
      end)

      mismatched = Enum.reject(candidates, &observations_match?(exp, control, &1))
      result = Scientist.Result.new(exp, control, candidates, mismatched)

      guarded exp, :publish, do: exp.module.publish(result)

      cond do
        Keyword.get(opts, :result, false) -> result
        Scientist.Observation.raised?(control) -> raise control.except
        Scientist.Observation.thrown?(control) -> throw control.except
        true -> control.value
      end
    else
      c.()
    end
  end
  def run(_, _), do: raise ArgumentError, message: "Experiment must have a control to run"

  defp eval_observable(experiment, {name, observable}) do
    Scientist.Observation.new(experiment, name, observable)
  end

  @doc """
  Returns true if the two observations match, reporting an error to the callback module
  if an exception is caught.
  """
  def observations_match?(experiment, control, candidate) do
    guarded experiment, :compare do
      Scientist.Observation.equivalent?(control, candidate, experiment.comparator)
    end
  end

  @doc """
  Returns true if the experiment should run, reporting an error to the callback module
  if an exception is caught.
  """
  def should_run?(experiment = %Scientist.Experiment{module: module}) do
    guarded experiment, :enabled, do: module.enabled? and run_if_allows?(experiment)
  end

  @doc """
  Returns the value of the experiment's run_if function, or true if one does not exist.
  Reports an error to the callback module if an exception is caught.
  """
  def run_if_allows?(experiment = %Scientist.Experiment{run_if_fn: f}) do
    guarded experiment, :run_if, do: is_nil(f) or f.()
  end

  @doc """
  Adds the given function to the experiment as the control.

  Raises ArgumentError if the given experiment already has a control.
  """
  def add_control(%Scientist.Experiment{observables: %{"control" => _}}, _) do
    raise ArgumentError, message: "Experiment can only have a single control"
  end
  def add_control(exp, observable), do: add_observable(exp, "control", observable)

  @doc """
  Adds the given function to the experiment as an observable.
  """
  def add_observable(exp, name, observable) do
    new_observables = exp.observables |> Map.put(name, observable)
    %__MODULE__{exp | observables: new_observables}
  end

  @doc """
  Adds a function to the experiment that is used to compare observations.
  """
  def compare_with(exp, c) do
    %__MODULE__{exp | comparator: c}
  end

  @doc """
  Adds a function to the experiment that is used to clean observed values.
  """
  def clean_with(exp, cleaner) do
    %__MODULE__{exp | clean: cleaner}
  end

  @doc """
  Adds a function to the experiment that is used to determine if it should run.
  """
  def set_run_if(exp, run_if_fn) do
    %__MODULE__{exp | run_if_fn: run_if_fn}
  end
end
