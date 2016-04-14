defmodule Scientist.MismatchError do
  @moduledoc """
  Raised at runtime when a mismatch occurs for an experiment configured to
  raise on mismatches.
  """
  defexception [:message, :result]

  def exception(opts) do
    result = Keyword.fetch!(opts, :result)
    message = "Experiment #{result.experiment.name} had mismatched observations"
    %__MODULE__{message: message, result: result}
  end
end
