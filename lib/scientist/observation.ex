defmodule Scientist.Observation do
  @moduledoc """
  A set of functions for working with experiment observations.

  A `Scientist.Observation` struct contains information about the execution of a
  given candidate, including its execution duration, value, and cleaned value.

  The timestamp is recorded as the system time, and along with the duration, is
  reported in milliseconds.
  """
  @timeunit :millisecond

  import Scientist.Experiment, only: [guarded: 3]

  defstruct name: "",
            experiment: nil,
            timestamp: nil,
            value: nil,
            cleaned_value: nil,
            exception: nil,
            stacktrace: nil,
            duration: nil

  @doc """
  Creates a new observation for `experiment`.

  Evaluates `candidate`, capturing any exceptions raised. The observation will
  be cleaned using the experiment's configured clean function.
  """
  def new(experiment, name, candidate) do
    observation = %Scientist.Observation{
      name: name,
      experiment: experiment,
      timestamp: System.system_time(@timeunit)
    }

    try do
      value = candidate.()

      cleaned =
        if experiment.clean do
          guarded(experiment, :clean, do: experiment.clean.(value))
        else
          value
        end

      duration = System.system_time(@timeunit) - observation.timestamp
      %__MODULE__{observation | value: value, duration: duration, cleaned_value: cleaned}
    rescue
      except ->
        %__MODULE__{observation | exception: {:raised, except}, stacktrace: System.stacktrace()}
    catch
      except ->
        %__MODULE__{observation | exception: {:thrown, except}, stacktrace: System.stacktrace()}
    end
  end

  @doc """
  Returns true if the observations match.

  The observations will be compared using the experiment's configured
  compare function.
  """
  def equivalent?(observation, other, compare \\ &Kernel.==/2) do
    case {observation.exception, other.exception} do
      {nil, nil} ->
        compare.(observation.value, other.value)

      {nil, _} ->
        false

      {_, nil} ->
        false

      {except, other_except} ->
        except == other_except
    end
  end

  @doc """
  Re-raises or throws the exception that occurred during observation, if any.
  """
  def except!(observation)
  def except!(%Scientist.Observation{exception: nil}), do: nil
  def except!(%Scientist.Observation{exception: {:raised, e}, stacktrace: s}), do: reraise(e, s)
  def except!(%Scientist.Observation{exception: {:thrown, e}}), do: throw(e)

  @doc """
  Returns true if the observation threw or raised an exception.
  """
  def except?(observation)
  def except?(%Scientist.Observation{exception: nil}), do: false
  def except?(_), do: true

  @doc """
  Returns true if the observation raised an exception.
  """
  def raised?(observation)
  def raised?(%Scientist.Observation{exception: {:raised, _}}), do: true
  def raised?(_), do: false

  @doc """
  Returns true if the observation threw an exception.
  """
  def thrown?(observation)
  def thrown?(%Scientist.Observation{exception: {:thrown, _}}), do: true
  def thrown?(_), do: false
end
