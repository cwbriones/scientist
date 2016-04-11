defmodule Scientist.Result do
  defstruct [
      experiment: nil,
      candidates: [],
      control: nil,
      mismatched: [],
      ignored: []
    ]

  alias __MODULE__
  alias Scientist.Experiment

  @doc """
  Creates a new Result from experiment, control, and observations.
  """
  def new(ex, control, candidates) do
    {ignored, mismatched} = evaluate_candidates(ex, control, candidates)

    %Result{
      experiment: ex,
      candidates: candidates,
      control: control,
      mismatched: mismatched,
      ignored: ignored
    }
  end

  @doc """
  Returns true if all observations matched the control, excluding ignored
  mismatches.
  """
  def matched?(result), do: not (mismatched?(result) or ignored?(result))

  @doc """
  Returns true if any experiment mismatches were ignored.
  """
  def ignored?(%Result{ignored: []}), do: false
  def ignored?(%Result{}), do: true

  @doc """
  Returns true if any observations failed to match the control, excluding
  ignored mismatches.
  """
  def mismatched?(%Result{mismatched: []}), do: false
  def mismatched?(%Result{}), do: true

  defp evaluate_candidates(ex, control, candidates) do
    candidates
      |> Enum.reject(&Experiment.observations_match?(ex, control, &1))
      |> Enum.partition(&Experiment.should_ignore_mismatch?(ex, control, &1))
  end
end
