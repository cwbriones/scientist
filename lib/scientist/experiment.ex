defmodule Scientist.Experiment do
  defstruct [
      name: "#{__MODULE__}",
      observables: %{},
      context: %{},
      run_if_fn: nil,
      before_run: nil,
      result: nil,
      clean: nil,
      ignore: [],
      comparator: &Kernel.==/2,
      raise_on_mismatches: false,
      module: Scientist.Default
    ]

  @callback enabled?() :: Boolean
  @callback publish(%Scientist.Result{}) :: any

  defmacro __using__(opts) do
    raise_on_mismatches = Keyword.get(opts, :raise_on_mismatches, false)
    quote do
      @behaviour unquote(__MODULE__)

      @doc """
      Creates a new experiment.
      """
      def new(name \\ name, opts \\ []) do
        context = Keyword.get(opts, :context, %{})
        should_raise =
          Keyword.get(opts, :raise_on_mismatches, unquote(raise_on_mismatches))

        unquote(__MODULE__).new(
            __MODULE__,
            name,
            context: Map.merge(default_context, context),
            raise_on_mismatches: should_raise
          )
      end

      @doc """
      Returns the default context for an experiment.
      """
      def default_context, do: %{}

      @doc """
      Returns the default name for an experiment.
      """
      def name, do: "#{__MODULE__}"

      @doc """
      Called when an experiment run raises an error during an operation.
      """
      def raised(experiment, operation, except), do: raise except

      @doc """
      Called when an experiment run throws an error during an operation.
      """
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
  def new(module, name, opts) do
    %__MODULE__{
      name: name,
      context: Keyword.get(opts, :context, %{}),
      module: module,
      raise_on_mismatches: Keyword.get(opts, :raise_on_mismatches, false)
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
      !exp.before_run or exp.before_run.()

      observations = exp.observables
      |> Enum.shuffle
      |> Enum.map(&(eval_observable(exp, &1)))
      |> Enum.to_list

      {[control], candidates} = Enum.partition(observations, fn o ->
        o.name == "control"
      end)

      result = Scientist.Result.new(exp, control, candidates)

      guarded exp, :publish, do: exp.module.publish(result)

      if exp.raise_on_mismatches and Scientist.Result.mismatched?(result) do
        raise Scientist.MismatchError, result: result
      end

      cond do
        Keyword.get(opts, :result, false) -> result
        Scientist.Observation.except?(control) -> Scientist.Observation.except!(control)
        true -> control.value
      end
    else
      c.()
    end
  end
  def run(_, _), do: raise ArgumentError, message: "Experiment must have a control to run"

  @doc """
  Returns true if an experiment determines a mismatch should be ignored, based on its
  ignore functions.
  """
  def should_ignore_mismatch?(exp, control, candidate) do
    ignores = exp.ignore |> Enum.reverse
    Enum.any?(ignores, fn i ->
      guarded exp, :ignore, do: i.(control.value, candidate.value)
    end)
  end

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
  def should_run?(experiment = %Scientist.Experiment{observables: obs, module: module}) do
    guarded experiment, :enabled do
      Enum.count(obs) > 1 and module.enabled? and run_if_allows?(experiment)
    end
  end

  @doc """
  Returns the value of the experiment's run_if function, or true if one does not exist.
  Reports an error to the callback module if an exception is caught.
  """
  def run_if_allows?(experiment = %Scientist.Experiment{run_if_fn: f}) do
    guarded experiment, :run_if, do: !f or f.()
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

  Raises Argument error if the given experiment already has an observable with `name`.
  """
  def add_observable(exp, name, observable) do
    if Map.has_key?(exp.observables, name) do
      message = "Experiment \"#{exp.name}\" already has an observable called \"#{name}\""
      raise ArgumentError, message: message
    else
      update_in(exp.observables, &(Map.put(&1, name, observable)))
    end
  end

  @doc """
  Adds a function to the experiment that is used to compare observations.
  """
  def compare_with(exp, c) do
    put_in(exp.comparator, c)
  end

  @doc """
  Adds an ignore function to the experiment. The experiment will ignore a mismatch whenever
  this function returns true.
  """
  def ignore(exp, i) do
    put_in(exp.ignore, [i | exp.ignore])
  end

  @doc """
  Adds a function to the experiment that is used to clean observed values.
  """
  def clean_with(exp, cleaner) do
    put_in(exp.clean, cleaner)
  end

  @doc """
  Adds a function to the experiment that is used to determine if it should run.
  """
  def set_run_if(exp, run_if_fn) do
    put_in(exp.run_if_fn, run_if_fn)
  end

  @doc """
  Adds a function to the experiment that should only execute when the experiment is run.
  """
  def set_before_run(exp, before_run) do
    put_in(exp.before_run, before_run)
  end
end
