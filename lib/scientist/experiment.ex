defmodule Scientist.Experiment do
  @moduledoc """
  A behaviour module for creating and running experiments.

  An experiment contains all information about how your control and candidate functions
  operate, and how their observations are reported. Experiments include functionality
  for determining when they should run and how they behave when exceptions are thrown.

  The macros exposed by `Scientist` are a thin wrapper around the functions in this
  module. If you would like to, you can use the corresponding functions to create
  and run your experiment.

  In addition to the required callbacks, you can also define custom defaults and
  exception handling behaviour.

  ## Custom Defaults

  `default_name/0` and `default_context/0` determine the default name and context,
  respectively, of unconfigured experiments in your module.

  ## Custom Exception Handling

  `raised/3` and `thrown/3` determine how your experiment will handle exceptions
  during an operation specified by the user. They receive the experiment as well
  as the operation name and exception. When left unspecified, exceptions thrown
  during an operation will be unhandled by `Scientist`.

  The following operations report exceptions:

  * `:enabled`
  * `:compare`
  * `:clean`
  * `:ignore`
  * `:run_if`
  """

  defstruct name: "#{__MODULE__}",
            candidates: %{},
            context: %{},
            run_if_fn: nil,
            before_run: nil,
            result: nil,
            clean: nil,
            ignore: [],
            comparator: &Kernel.==/2,
            raise_on_mismatches: false,
            module: Scientist.Default

  @doc """
  Returns `true` if the experiment should be run.

  If a falsey value is returned, the candidate blocks of the experiment
  will be ignored, only running the control.
  """
  @callback enabled?() :: Boolean | nil

  @doc """
  Publish the result of an experiment.
  """
  @callback publish(result :: %Scientist.Result{}) :: any

  defmacro __using__(opts) do
    raise_on_mismatches = Keyword.get(opts, :raise_on_mismatches, false)

    quote do
      @behaviour unquote(__MODULE__)

      @doc """
      Creates a new experiment.
      """
      def new(name \\ default_name, opts \\ []) do
        context = Keyword.get(opts, :context, %{})
        should_raise = Keyword.get(opts, :raise_on_mismatches, unquote(raise_on_mismatches))

        unquote(__MODULE__).new(
          name,
          module: __MODULE__,
          context: Map.merge(default_context, context),
          raise_on_mismatches: should_raise
        )
      end

      @doc """
      Returns the default context for an experiment.

      Any additional context passed to `new/2` will be merged with the default context.
      """
      def default_context, do: %{}

      @doc """
      Returns the default name for an experiment.
      """
      def default_name, do: "#{__MODULE__}"

      @doc """
      Called when an experiment run raises an error during an operation.
      """
      def raised(experiment, operation, except), do: raise(except)

      @doc """
      Called when an experiment run throws an error during an operation.
      """
      def thrown(_experiment, _operation, except), do: throw(except)

      defoverridable default_context: 0, default_name: 0, raised: 3, thrown: 3
    end
  end

  @doc """
  Creates an experiment.

  Creates an experiment with the `name` and `opts`.

  The following options are available:
  * `:module` - The callback module to use, defaults to `Scientist.Default`.
  * `:context` - A map of values to be stored in an observation, defaults to `%{}`.
  * `:raise_on_mismatches` - If `true`, any mismatches in this experiment's observations
  will raise a `Scientist.MismatchError`, defaults to `false`.
  """
  def new(name \\ "#{__MODULE__}", opts \\ []) do
    %__MODULE__{
      name: name,
      module: Keyword.get(opts, :module, Scientist.Default),
      context: Keyword.get(opts, :context, %{}),
      raise_on_mismatches: Keyword.get(opts, :raise_on_mismatches, false)
    }
  end

  @doc """
  Executes the given block, reporting exceptions.

  Executes `block` and calls `thrown/3` or `raised/3` with the given reason if the block
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
  Runs the experiment.

  If `enabled?/0` or a configured run_if function return a falsey value, the experiment
  will not be run and only the control will be executed.

  Raises `Scientist.MissingControlError` if the experiment has no control.

  Raises `Scientist.MismatchError` if the experiment has mismatched observations and is
  configured with `raise_on_mismatched: true`.
  """
  def run(exp, opts \\ [])

  def run(exp = %Scientist.Experiment{candidates: %{"control" => c}}, opts) do
    if should_run?(exp) do
      !exp.before_run or exp.before_run.()

      observations =
        exp.candidates
        |> Enum.shuffle()
        |> Enum.map(&eval_candidate(exp, &1))
        |> Enum.to_list()

      {[control], candidates} =
        Enum.partition(observations, fn o ->
          o.name == "control"
        end)

      result = Scientist.Result.new(exp, control, candidates)

      guarded(exp, :publish, do: exp.module.publish(result))

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

  def run(ex, _), do: raise(Scientist.MissingControlError, experiment: ex)

  @doc """
  Returns true if a mismatch should be ignored.

  Runs each of the configured ignore functions in turn, ignoring a mismatch when
  any of them return `true`.

  Reports an `:ignore` error to the callback module if an exception is caught.
  """
  def should_ignore_mismatch?(exp, control, candidate) do
    ignores = exp.ignore |> Enum.reverse()

    Enum.any?(ignores, fn i ->
      guarded(exp, :ignore, do: i.(control.value, candidate.value))
    end)
  end

  defp eval_candidate(experiment, {name, candidate}) do
    Scientist.Observation.new(experiment, name, candidate)
  end

  @doc """
  Returns true if the given observations match.

  This uses the experiment's compare function, if any. If none is configured,
  `==/2` will be used.

  Reports a `:compare` error to the callback module if an exception is caught.
  """
  def observations_match?(experiment, control, candidate) do
    guarded experiment, :compare do
      Scientist.Observation.equivalent?(control, candidate, experiment.comparator)
    end
  end

  @doc """
  Returns true if the experiment should run.

  Reports an `:enabled` error to the callback module if an exception is caught.
  """
  def should_run?(experiment = %Scientist.Experiment{candidates: obs, module: module}) do
    guarded experiment, :enabled do
      Enum.count(obs) > 1 and module.enabled? and run_if_allows?(experiment)
    end
  end

  @doc """
  Returns the value of the experiment's run_if function.

  If the experiment has no run_if function configured, `true` is returned.

  Reports a `:run_if` error to the callback module if an exception is caught.
  """
  def run_if_allows?(experiment = %Scientist.Experiment{run_if_fn: f}) do
    guarded(experiment, :run_if, do: !f or f.())
  end

  @doc """
  Adds `fun` to the experiment as the control.

  Raises `Scientist.DuplicateError` if the experiment already has a control.
  """
  def add_control(exp = %Scientist.Experiment{candidates: %{"control" => _}}, _) do
    raise Scientist.DuplicateError, experiment: exp, name: "control"
  end

  def add_control(exp, fun), do: add_candidate(exp, "control", fun)

  @doc """
  Adds `fun` to the experiment as a candidate.

  Raises `Scientist.DuplicateError` if the experiment already has a candidate with `name`.
  """
  def add_candidate(exp, name \\ "candidate", fun) do
    if Map.has_key?(exp.candidates, name) do
      raise Scientist.DuplicateError, experiment: exp, name: name
    else
      update_in(exp.candidates, &Map.put(&1, name, fun))
    end
  end

  @doc """
  Adds a function to the experiment that is used to compare observations.

  If an exception is thrown in `compare_fn`, it will be reported through the `thrown` and `raised`
  callbacks as operation `:compare`.
  """
  def compare_with(exp, compare_fn) do
    put_in(exp.comparator, compare_fn)
  end

  @doc """
  Adds an ignore function to the experiment.

  The experiment will ignore a mismatch whenever this function returns true. There is no limit
  on the number of ignore functions that can be configured.

  If an exception is thrown in `ignore_fn`, it will be reported through the `thrown` and `raised`
  callbacks as operation `:ignore`.
  """
  def ignore(exp, ignore_fn) do
    put_in(exp.ignore, [ignore_fn | exp.ignore])
  end

  @doc """
  Adds a function to the experiment that is used to clean observed values.

  When handling observations, the result of `cleaner` will be available under `cleaned_value`.

  If an exception is thrown in `cleaner`, it will be reported through the `thrown` and `raised`
  callbacks as operation `:clean`.
  """
  def clean_with(exp, cleaner) do
    put_in(exp.clean, cleaner)
  end

  @doc """
  Adds a function to the experiment that is used to determine if it should run.

  If this function returns `false`, the experiment will not be run.

  If an exception is thrown in `run_if_fn`, it will be reported through the `thrown` and `raised`
  callbacks as operation `:run_if`.
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
