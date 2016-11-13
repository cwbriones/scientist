# Scientist

[![Build Status](https://travis-ci.org/cwbriones/scientist.svg?branch=master)](https://travis-ci.org/cwbriones/scientist)
[![Coverage Status](https://coveralls.io/repos/github/cwbriones/scientist/badge.svg?branch=master)](https://coveralls.io/github/cwbriones/scientist?branch=master)

A library for carefully refactoring critical paths in your elixir appplication.

This is an elixir clone of the ruby gem [scientist](https://github.com/github/scientist).

## Wait, why be a Scientist?

Suppose you decide to add a new caching layer to your production application, while still being able to make the same guarantees about your data. By processing your new caching strategy through Scientist you'll be able to

* Run both the old and the new code in random order
* Monitor timing for each strategy
* Compare their results and find any mismatches
* Rescue and report any exceptions thrown in your new code
* Publish all of this information in a manner of your choosing.

Externally, a Scientist experiment behaves exactly the same as its control block, returning the value of the control as well as re-raising any of its exceptions.

```elixir
defmodule MyPhoenixApp.UserController do
  use Scientist
  use MyPhoenixApp.Web, :controller

  alias MyPhoenixApp.User
  alias MyPhoenixApp.Repo

  plug :action

  def get_user(id) do
    # Let's get down to business, with science!
    science "New ETS cache for users" do
      control do: Repo.get(User, id)
      candidate do: MyETSCache.get(User, id)
    end
  end

  # ... other controller logic
end
```

# Rolling your own Experiment

Experiments aren't useful on their own. You need to be able to report their results and control
their execution. To define your own custom experiment, you need to `use Scientist.Experiment` and
implement a few callbacks.

```elixir
defmodule MyCustomExperiment do
  use Scientist.Experiment

  # Required callbacks: publish/1, enabled?/0
  # See "Enabling Experiments" and "Publishing" below
  defdelegate [enabled?(), publish(result)], to: Scientist.Default

  # Optional callbacks
  # Default name
  def default_name, do: "My custom experiment"
  # Default context, see "Need some context?" below
  def default_context, do: %{}
end
```

Then when using `Scientist` you can specify your custom experiment to be used instead of
`Scientist.Default`:
```elixir
defmodule UserController do
  use Scientist, experiment: MyCustomExperiment

  # Now let's get some science done!
end
```

Now all calls to `science` will use `MyCustomExperiment.new/2` for setup.

## Custom Comparison

Out of the box, Scientist will compare observed values with `Kernel.==/2` to see if they match. You can override this with a comparison block.

```elixir
def get_user(id) do
  science "New ETS cache for users" do
    control do: Repo.get(User, id)
    candidate do: MyETSCache.get(User, id)

    # We only care if the user's status is updated.
    compare(%{status: sa}, %{status: sb}) do
      sa == sb
    end
  end
end
```

## Need some context?

Sometimes, you need more information about the environment when checking the results of your experiment.
In these cases, you can pass a map of values to your experiment before it's run:
```elixir
def get_user(id) do
  # Perhaps the cache is filling too quickly
  c = %{cache_size: MyETSCache.size(User)}
  science "New ETS cache for users", context: c, do
    control do: Repo.get(User, id)
    candidate do: MyETSCache.get(User, id)
  end
end
```
Then the context will be available as `result.experiment.context` in your publisher.

## Doing some cleaning

Should you find yourself with *too much* information during an experiment, you can pass
an optional `clean` block to extract the relevant data. Then only the cleaned
values will be compared and you won't erroneously report mismatches about other data.

```elixir
def get_user(id) do
  science "New ETS cache for users" do
    control do: Repo.get(User, id)
    candidate do: MyETSCache.get(User, id)
    clean(_user = %{status: status}) do
      status
    end
  end
end
```

Both `value` and `cleaned_value` will be later available in your observations.

## Expecting failure

In some cases you know ahead of time that your experiment will mismatch. You could be replicating
your data to a new store in pieces, or moving to a cache with less recency.

Fortunately, `Scientist` allows you to specify these situations and ignore mismatches outright when they occur.

```elixir
def get_user(id) do
  science "New ETS cache for users" do
    control do: Repo.get(User, id)
    candidate do: MyETSCache.get(User, id)

    ignore(control, _candidate) do
      # Cached entries have a 1 min TTL
      # We expect a mismatch when the DB was updated sooner.
      within_last_minute?(control.updated_at)
    end
  end
end
```

You can even choose to avoid running the experiment entirely with a `run_if` block:

```elixir
def get_posts_for_user(user) do
  science "Data should be consistent during migration" do
    run_if do
      # It clearly won't match if we haven't moved their data.
      User.is_migrated?(user)
    end
    control do: Repo.get_by(Post, user_id: user.id)
    candidate do: NewRepo.get_by(Post, user_id: user.id)
  end
end
```

## Enabling experiments

In addition to `run_if`, custom experiments use the `enabled?/0` callback to determine whether or not they should run. You must implement this function in your experiment module:

```elixir
defmodule MyCustomExperiment do
  use Scientist.Experiment

  @percent_enabled 0.5

  # Let's not go too crazy, let's say this should run half the time.
  def enabled?, do: :random.uniform < @percent_enabled
end
```

## Publishing

Scientist doesn't care how you choose to publish your results - you can send results to a batching
GenServer process or simply use Logger. However you do it is up to you. You are however, required
to implement publishing in *some form*.

The `publish/1` callback is given a `Scientist.Result` struct containing all observations made, including
their durations, values, and whether or not there was a mismatch.

```elixir
defmodule MyCustomExperiment do
  use Scientist.Experiment
  alias Scientist.Result

  def enabled?, do: true

  def publish(result) do
    MyPublisher.publish("control", result.experiment.name, result.control.duration)
    Enum.each(result.candidates, fn can ->
      MyPublisher.publish(candidate.name, result.experiment.name, candidate.duration)
    end)
    if Result.mismatched?(result) do
      MyPublish.report_mismatch(result.experiment.name, result.mismatched)
    end
  end
end
```

## Operator Error

We've all done it before. Sooner or later you'll configure your experiment with blocks that may raise an
exception. In these situations you can use the optional `raised/3` and `thrown/3` callbacks so that your
experiment will continue in some fashion without complete failure.
```elixir
defmodule MyCustomExperiment do
  use Scientist.Experiment

  # ... implementing required callbacks ...

  def raised(ex, operation, except) do
    IO.puts "Experiment failure in \"#{ex.name}\": #{operation} raised #{except.message}"
  end
  def thrown(ex, operation, except) do
    IO.puts "Experiment failure in \"#{ex.name}\": #{operation} threw #{except}"
  end
end
```
Each function is called with the name of the internal operation that failed:
* `:publish` - Exception raised within `publish/1`
* `:enabled` - Exception raised within `enabled?/0`
* `:compare` - Exception raised during comparison
* `:clean`   - Exception raised during cleaning
* `:ignore`  - Exception raised within an ignore block
* `:run_if`  - Exception raised within an run_if block

If these functions are not defined, `Scientist` will not handle the exception raised.

## Forcing errors

It can be useful to force `Scientist` to notify you of any mismatches that occur during testing.  Within a custom experiment or a single experiment, you can set `raise_on_mismatches: true` to raise a `Scientist.MismatchError` when observations don't match.

```elixir
# Raise on any individual experiment using this module
defmodule MyCustomExperiment do
  use Scientist.Experiment, raise_on_mismatches: true
  # ... implementing required callbacks ...
end

# Within a single experiment
science "this should never mismatch", raise_on_mismatches: true do
  # Same ol' experiment configuration
end
```

This setting is purposefully verbose, as you shouldn't be affecting the behavior of your application
like this in production.

## Science isn't magic

Some people prefer to avoid a DSL, as it can obfuscate your code and possibly raise strange, untraceable
errors. `science` and its friends are macros that simply create an experiment using the module you
specify and then call `Scientist.Experiment` to configure and run it.

You can do this for yourself, although it can seem a bit verbose. Fortunately, `|>` removes a bit of boilerplate for us.

```elixir
def get_user(id) do
  import Scientist.Experiment

  context = %{cache_size: MyETSCache.size(User)}

  MyCustomExperiment.new("New ETS cache for users", context: context)
  |> add_control(fn -> Repo.get(User, id) end)
  |> add_candidate(fn -> MyETSCache.get(User, id) end)
  |> clean_with(fn %{status: status} -> status end)
  |> run
end
```

# Now can I science?

You should keep a few things in mind before you jump into an experiment.

## Only experiment with immutable or transient data

You should only use Scientist when touching code that does operations on read-only data. You don't want to alter any code that does required mutation or persistence, as you wouldn't be able to guarantee its execution. In these cases, such as data migration, it would be best to write to both stores and check for
any inconsistencies with a single experiment during reads.

## (Avoid) Multiple candidates

You can also always have more than one candidate block in a single experiment, but it can make your results harder to interpret while also adding additional execution time. You can distinguish between candidate blocks by giving them unique names:
```elixir
def get_user(id) do
  science "Trying ALL the caching strategies" do
    control do: Repo.get(User, id)
    candidate "MyETSCache", do: MyETSCache.get(User, id)
    candidate "ConCache", do: ConCache.get(User, id)
    candidate "RedisCache", do: RedisCache.get(User, id)
  end
end
```

## I don't care about results

If you only care about timing data or new code stability, you can ignore results entirely by passing
compare blocks that are always true: `compare(_, _) do: true`

# Installation

Scientist is available on [Hex](https://hex.pm/packages/scientist). It can be installed by adding it to your
list of dependencies in `mix.exs`:
```elixir
  def deps do
    [{:scientist, "~> 0.2.0"}]
  end
```

# License

Scientist is licensed under the MIT License. See [LICENSE](https://github.com/cwbriones/scientist/blob/master/LICENSE) for the full text.
