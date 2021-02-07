defmodule Grouper.Group do
  @moduledoc """
  Starting a group turns whatever is starting it into a "group". This is
  typically either run from a standalone process or under a supervisor as the
  first child. It is not usually necessary under an `Application`, as the
  application itself is used as a group identifier.

  In either case, it will "commandeer" the group-leader setting of that
  calling process, making all subsequent processes started use it as leader
  which is necessary for Grouper's functionality to work.

  ## Standalone

  Typically run in tests or scripts,

  In the rare event that two groups must run under the same supervisor, it is
  possible to specify a "group key" to distinguish the two groups.

  ## Application

  When running under an application, it's assumed to be your group.  As a
  convenience, the OTP environment

  Attempting to start a group under an application will return a
  `:group_under_app` error by default. Forcing a group to run under a
  supervisor can break OTP shutdown behavior and is almost always a terrible
  idea.

  ## Restart Behavior

  When run under a supervisor, a group may be restarted automatically should
  it fail. A flag is set in the supervisor's process dictionary that is used
  to detect this.

  Since death of a group_leader is fairly catastrophic, this process will not
  try to restart it. Rather, all subsequent attempts will automatically fail
  with a `:group_leader_died` error.

  This should fail the supervisor fairly quickly which will, in turn, more
  properly clean up the whole tree. Given that group leaders very rarely
  fail, this shouldn't be a common occurence.

  ## Options

    * `:group_key` - when more than one group is running under a single
      supervisor, this key is used to disambiguate start and stop requests.

    * `:force_group` - when set to `true`, will start a group under an
      application. This is dangerous as it interferes with OTP's application
      shutdown behavior.

    Additional options are passed on to the
    `Grouper.GroupLeader.start_link/1` function.

  """
  require Logger

  alias Grouper.GroupLeader

  @doc """
  initialize this process and its descendants to be their own group
  """
  @spec start_link(keyword()) :: {:ok, pid()} | :ignore | {:error, any}
  def start_link(opts \\ []) do
    {group_key, opts} = Keyword.pop(opts, :group_key, :default_group_key)
    {force_group, opts} = Keyword.pop(opts, :force_group, false)

    opts =
      opts
      |> Keyword.put(:parent, self())
      |> Keyword.put_new(:commandeer, true)

    app = :application.get_application()

    cond do
      app != :undefined and not force_group ->
        Logger.error(
          "groups under applications can break shutdown, requires `force_group` option to override"
        )

        {:error, :group_under_app}

      Process.get({:group_active, group_key}) == true ->
        {:error, :group_leader_died}

      app == :undefined or force_group ->
        Process.put({:group_active, group_key}, true)
        GroupLeader.start_link(opts)
    end
  end

  @doc """
  deactivates group behavior for this process
  """
  @spec stop(keyword()) :: :ok
  def stop(opts \\ []) do
    {group_key, _opts} = Keyword.pop(opts, :group_key, :default_group_key)

    # ignores extra options to allow symmetry with `start_link/1`

    case Process.delete({:group_active, group_key}) do
      true ->
        Process.group_leader()
        |> GenServer.stop()

      nil ->
        raise Grouper.NoGroupError, reason: "no running group to stop"
    end
  end

  @doc """
  provides instructions for supervisors to run a group process
  """
  @spec child_spec(keyword()) :: {:ok, Supervisor.child_spec()}
  def child_spec(opts) do
    cspec =
      opts
      |> GroupLeader.child_spec()
      |> Map.put(:start, {__MODULE__, :start_link, opts})

    {:ok, cspec}
  end
end
