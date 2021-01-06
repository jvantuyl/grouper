defmodule Grouper.Group do
  @moduledoc """
  Turns whatever is supervising it into a "group".

  When running under an application, it's assumed to be your "group". If the
  `force_group` option is set to true, then it will force a group even when
  running under an application. Note that this may interfere with application
  shutdown, as it can't locate rogue processes by their group leader like it
  normally does.

  Since death of a group_leader is fairly catastrophic, this process will not
  try to restart it. Rather, it will automatically fail on restart attempts.
  This should fail the supervisor fairly quickly which will, in turn, more
  properly clean up the whole tree. Given that group leaders very rarely
  fail, this shouldn't be a common occurence.
  """
  require Logger

  def start_link(opts \\ []) do
    {force_group, opts} = Keyword.pop(opts, :force_group, false)

    opts =
      opts
      |> Keyword.put(:parent, self())
      |> Keyword.put(:commandeer, true)

    app = :application.get_application()

    cond do
      Process.get(:group_active) ->
        # this is set in the supervisor, so it picks up on restarts
        gl = Process.group_leader()

        if Process.alive?(gl) do
          Logger.warn("attempted to restart already running group leader")
          {:ok, gl}
        else
          {:error, :group_leader_died}
        end

      app == :undefined or force_group ->
        Process.put(:group_active, true)
        Grouper.Group.Leader.start_link(opts)

      is_atom(app) ->
        Process.put(:group_active, true)
        Grouper.Group.Leader.start_link(opts)
    end
  end

  def stop() do
    case Process.delete(:group_active) do
      true ->
        Process.group_leader()
        |> GenServer.stop()

      nil ->
        raise Grouper.NoGroupError, reason: "no running group to stop"
    end
  end

  def child_spec(opts) do
    opts = Keyword.put_new(opts, :commandeer, true)

    cspec =
      opts
      |> Grouper.Group.Leader.child_spec()
      |> Map.put(:start, {__MODULE__, :start_link, opts})

    {:ok, cspec}
  end
end
