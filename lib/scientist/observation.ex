defmodule Scientist.Observation do
  @timeunit :milli_seconds

  require Scientist.Experiment
  import  Scientist.Experiment, only: [guarded: 3]

  defstruct [
      name: "",
      experiment: nil,
      timestamp: nil,
      value: nil,
      cleaned_value: nil,
      exception: nil,
      duration: nil,
    ]

  @doc """
  Creates a new observation for the experiment.

  Evaluates observable, capturing any exceptions raised.
  """
  def new(experiment, name, observable) do
    observation = %Scientist.Observation{
      name: name,
      experiment: experiment,
      timestamp: System.system_time(@timeunit),
    }
    try do
      value = observable.()
      cleaned = if experiment.clean do
        guarded experiment, :clean, do: experiment.clean.(value)
      else
        value
      end
      duration = System.system_time(@timeunit) - observation.timestamp
      %Scientist.Observation{observation | value: value, duration: duration, cleaned_value: cleaned}
    rescue
      except -> put_in observation.exception, {:raised, except}
    catch
      except -> put_in observation.exception, {:thrown, except}
    end
  end

  @doc """
  Returns true if the observations match with the compare function.

  Defaults to comparing by a direct equality.
  """
  def equivalent?(observation, other, compare \\ &Kernel.==/2) do
    case {observation.exception, other.exception} do
      {nil, nil} ->
        compare.(observation.value, other.value)
      {nil, _} -> false;
      {_, nil} -> false;
      {except, other_except} -> except == other_except
    end
  end

  @doc """
  Re-raises or throws the exception that occurred during observation, if any.
  """
  def except!(%Scientist.Observation{exception: nil}), do: nil
  def except!(%Scientist.Observation{exception: {:raised, e}}), do: raise e
  def except!(%Scientist.Observation{exception: {:thrown, e}}), do: throw e

  @doc """
  Returns true if the observation threw or raised an exception.
  """
  def except?(%Scientist.Observation{exception: nil}), do: false
  def except?(_), do: true

  @doc """
  Returns true if the observation raised an exception.
  """
  def raised?(%Scientist.Observation{exception: {:raised, _}}), do: true
  def raised?(_), do: false

  @doc """
  Returns true if the observation threw an exception.
  """
  def thrown?(%Scientist.Observation{exception: {:thrown, _}}), do: true
  def thrown?(_), do: false
end
