defmodule Scientist.Result do
  defstruct [
      experiment: nil,
      candidates: [],
      control: nil,
      mismatched: [],
      ignored: []
    ]

  def new(experiment, control, candidates) do
    {mismatched, ignored} = evaluate_candidates(experiment, control, candidates)
    %Scientist.Result{
      experiment: experiment,
      candidates: candidates,
      control: control,
      mismatched: mismatched,
      ignored: ignored
    }
  end

  def matched?(result), do: not (mismatched?(result) or ignored?(result))

  def ignored?(%Scientist.Result{ignored: []}), do: false
  def ignored?(%Scientist.Result{}), do: true

  def mismatched?(%Scientist.Result{mismatched: []}), do: false
  def mismatched?(%Scientist.Result{}), do: true

  defp evaluate_candidates(experiment, control, candidates) do
    filter_fn = &Scientist.Observation.equivalent?(control, &1, experiment.comparator)

    mismatched = Enum.reject(candidates, filter_fn)

    # {mismatched, []}
    {[], []}
  end
end
