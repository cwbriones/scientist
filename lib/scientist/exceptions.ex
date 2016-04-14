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

defmodule Scientist.DuplicateError do
  @moduledoc """
  Raised at runtime when an experiment is assigned a duplicate candidate.
  """
  defexception [:message, :experiment, :name]

  def exception(opts) do
    experiment = Keyword.fetch!(opts, :experiment)
    name = Keyword.fetch!(opts, :name)
    message = "Experiment \"#{experiment.name}\" already has an observable called \"#{name}\""
    %__MODULE__{message: message, experiment: experiment, name: name}
  end
end

defmodule Scientist.MissingControlError do
  @moduledoc """
  Raised at runtime when an experiment is run without a control.
  """
  defexception [:message, :experiment]

  def exception(opts) do
    experiment = Keyword.fetch!(opts, :experiment)
    message = "Experiment \"#{experiment.name}\" was run without a control"
    %__MODULE__{message: message, experiment: experiment}
  end
end
