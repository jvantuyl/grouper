defmodule Grouper do
  @moduledoc """
  Isolates groups of process subtrees together for configuration and name
  registration purposes.

  * Do you struggle with Elixir's global namespace for process names?
  * Do all of your tests run synchronously because of this collisions?
  * Do you mutate your application environment during tests?

  If the above problems sounds familiar, `Grouper` might be for you.

  ## Usage

  Simply start your `GenServer`s like this:

      GenServer.start_link(mod, arg, name: {:via, Grouper.Registry})

  And access configuration like this:

      Grouper.Config.get(:key)

  In tests, scripts and IEX; initialize a group with:

      {:ok, _} = Grouper.start_link()

  Or run a single function in its own group like this:

      Grouper.exec!(&MyApp.my_task/0)

  During normal application runtime, each application gets its own namespace
  for processes and has isolated config.

  During tests, however, each test can get its own group with isolated naming
  and configuration. This makes it trivial to run all of your tests
  asynchronously, eliminates the need to use global config for things like
  mocking, and prevents config mutations in different tests from interfering
  with each other.

  Scripts and IEX can similarly benefit from group isolation with a single
  command, thereby rounding out behavior to be identical in all common
  execution environments.

  ## Migration

  For convenience, the OTP config environment is loaded into the config for
  you, simplifying migration from older, global configuration. This can be
  suppressed if desired (see `Grouper.Config.suppress_otp_env/1` for
  details).
  """

  defdelegate start_link(opts \\ []), to: Grouper.Group
  defdelegate stop(opts \\ []), to: Grouper.Group

  @doc """
  execute a function in its own group, returning an `:ok` or `:error` result

  Options are passed through to `Grouper.start_link/1` and `Grouper.stop/1`.
  """
  @spec exec(fun(), keyword()) :: {:ok, any()} | {:error, any()}
  def exec(fun, opts \\ []) do
    case Grouper.Group.start_link(opts) do
      {:ok, group_pid} ->
        group_pid

      {:error, _} = err ->
        throw(err)
    end

    try do
      {:ok, fun.()}
    after
      :ok = Grouper.Group.stop(opts)
    end
  catch
    {:error, _} = err ->
      err
  end


  @doc """
  execute a function in its own group, raising an exception on error

  Options are passed through to `Grouper.start_link/1` and `Grouper.stop/1`.
  """
  @spec exec!(fun(), keyword()) :: any() | no_return()
  def exec!(fun, opts \\ []) do
    case exec(fun, opts) do
      {:ok, result} ->
        result

      {:error, :no_group} ->
        raise Grouper.NoGroupError

      {:error, reason} ->
        raise RuntimeError, reason: reason
    end
  end

  @doc """
  execute a function in its own group, returning an `:ok` or `:error` result

  Options are passed through to `Grouper.start_link/1` and `Grouper.stop/1`.
  """
  @spec exec(atom(), atom(), [any()], keyword()) :: {:ok, any()} | {:error, any()}
  def exec(m, f, a, opts \\ []) when is_atom(m) and is_atom(f) and is_list(a) do
    exec(fn -> apply(m, f, a) end, opts)
  end

  @doc """
  execute a function in its own group, raising an exception on error

  Options are passed through to `Grouper.start_link/1` and `Grouper.stop/1`.
  """
  @spec exec!(atom(), atom(), [any()], keyword()) :: any()
  def exec!(m, f, a, opts \\ []) when is_atom(m) and is_atom(f) and is_list(a) do
    exec!(fn -> apply(m, f, a) end, opts)
  end
end
