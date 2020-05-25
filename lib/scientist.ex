defmodule Scientist do
  @moduledoc ~S"""
  A library for carefully refactoring critical paths in your elixir application.
  """

  defmacro __using__(opts) do
    mod = Keyword.get(opts, :experiment, Scientist.Default)

    quote do
      import unquote(__MODULE__)

      Module.put_attribute(__MODULE__, :scientist_experiment, unquote(mod))
    end
  end

  @doc """
  Creates a new experiment.

  Creates an experiment with `name` and `opts`. The block will behave the same as the
  control block given, returning the same value and raising the same exceptions.

  The stacktrace of the raised exceptions will be preserved.

  See `Scientist.Experiment.new/2` for a list of available options.
  """
  defmacro science(name, opts \\ [], do: block) do
    should_run = Keyword.get(opts, :run, true)
    exp_opts = Keyword.delete(opts, :run)

    quote do
      var!(ex, Scientist) = @scientist_experiment.new(unquote(name), unquote(exp_opts))
      unquote(block)

      if unquote(should_run) do
        Scientist.Experiment.run(var!(ex, Scientist))
      else
        var!(ex, Scientist)
      end
    end
  end

  @doc """
  Adds a control block to the experiment created in `science/3`.

  See `Scientist.Experiment.add_control/2`.
  """
  defmacro control(do: block) do
    quote do
      c = fn -> unquote(block) end
      var!(ex, Scientist) = Scientist.Experiment.add_control(var!(ex, Scientist), c)
    end
  end

  @doc """
  Adds a candidate block to the experiment created in `science/3`.

  See `Scientist.Experiment.add_candidate/2`.
  """
  defmacro candidate(name \\ "candidate", do: block) do
    quote do
      c = fn -> unquote(block) end

      var!(ex, Scientist) =
        Scientist.Experiment.add_candidate(var!(ex, Scientist), unquote(name), c)
    end
  end

  @doc """
  Adds an ignore block to the experiment created in `science/3`.

  See `Scientist.Experiment.ignore/2`.
  """
  defmacro ignore(do: block) do
    quote do
      i = fn _, _ -> unquote(block) end
      var!(ex, Scientist) = Scientist.Experiment.ignore(var!(ex, Scientist), i)
    end
  end

  @doc """
  Adds an ignore block to the experiment created in `science/3`.

  The control and candidate values will be bound to the declared parameters in order.

  See `Scientist.Experiment.ignore/2`.
  """
  defmacro ignore(x, y, do: block) do
    quote do
      i = fn unquote(x), unquote(y) -> unquote(block) end
      var!(ex, Scientist) = Scientist.Experiment.ignore(var!(ex, Scientist), i)
    end
  end

  @doc """
  Adds a compare block to the experiment created in `science/3`.

  The control and candidate values will be bound to the declared parameters in order.

  See `Scientist.Experiment.compare_with/2`.
  """
  defmacro compare(x, y, do: block) do
    quote do
      c = fn unquote(x), unquote(y) -> unquote(block) end
      var!(ex, Scientist) = Scientist.Experiment.compare_with(var!(ex, Scientist), c)
    end
  end

  @doc """
  Adds a clean function to the experiment created in `science/3`.

  The observed values will be bound to the parameter given.

  See `Scientist.Experiment.clean_with/2`.
  """
  defmacro clean(x, do: block) do
    quote do
      c = fn unquote(x) -> unquote(block) end
      var!(ex, Scientist) = Scientist.Experiment.clean_with(var!(ex, Scientist), c)
    end
  end

  @doc """
  Adds a before_run function to the experiment created in `science/3`.

  See `Scientist.Experiment.set_before_run/2`.
  """
  defmacro before_run(do: block) do
    quote do
      b = fn -> unquote(block) end
      var!(ex, Scientist) = Scientist.Experiment.set_before_run(var!(ex, Scientist), b)
    end
  end

  @doc """
  Adds a run_if function to the experiment created in `science/3`.

  See `Scientist.Experiment.set_run_if/2`.
  """
  defmacro run_if(do: block) do
    quote do
      r = fn -> unquote(block) end
      var!(ex, Scientist) = Scientist.Experiment.set_run_if(var!(ex, Scientist), r)
    end
  end
end
