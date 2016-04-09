defmodule Scientist.Observation do
  @timeunit :milli_seconds

  defstruct [
      name: "",
      experiment: nil,
      timestamp: nil,
      value: nil,
      exception: nil,
      duration: nil,
    ]

  def new(experiment, name, observable) do
    observation = %Scientist.Observation{
      name: name,
      experiment: experiment,
      timestamp: System.system_time(@timeunit),
    }
    try do
      value = observable.()
      duration = System.system_time(@timeunit) - observation.timestamp
      %Scientist.Observation{observation | value: value, duration: duration}
    rescue
      except ->
        %Scientist.Observation{observation | exception: except}
    catch
      except ->
        %Scientist.Observation{observation | exception: except}
    end
  end

  def equivalent?(observation, other, compare) do
    case {observation.exception, other.exception} do
      {nil, nil} ->
        compare.(observation.value, other.value)
      {nil, _} -> false;
      {_, nil} -> false;
      {except, other_except} -> except == other_except
    end
  end

  def raised?(%Scientist.Observation{exception: e}), do: not is_nil(e)
end
