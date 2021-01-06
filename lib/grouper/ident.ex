defmodule Grouper.Ident do
  @moduledoc """
  Functions for identifying group leader types.
  """
  @compile {:inline, identify_gl_module: 2}

  alias Grouper.Group.Leader

  @typedoc "type of group leader process"
  @type group_leader_type() ::
          app_leader() | grouper_leader() | io_leader() | shell_leader() | user_leader()
  @type app_leader :: {:application, atom(), pid()}
  @type grouper_leader :: {:group, group_name :: atom(), :ets.tab(), pid()}
  @type io_leader :: {:capture_io, pid()}
  @type shell_leader :: {:shell, pid()}
  @type user_leader :: {:user, pid()}

  @typedoc "possible errors identifying group leaders"
  @type group_leader_errors() :: :dead | :unknown_type

  @doc """
  Identifies the type of group leader for current process.
  """
  @spec identify_group_leader() :: {:ok, group_leader_type()} | {:error, group_leader_errors()}
  def identify_group_leader() do
    Process.group_leader()
    |> identify_group_leader()
  end

  @doc """
  Identifies the type of group leader by its pid.
  """
  @spec identify_group_leader(pid()) ::
          {:ok, group_leader_type()} | {:error, group_leader_errors()}
  def identify_group_leader(pid) when is_pid(pid) do
    if not Process.alive?(pid) do
      throw({:error, :dead})
    end

    if pid == Process.whereis(:user) do
      throw({:ok, {:user, pid}})
    end

    {:dictionary, dict} = Process.info(pid, :dictionary)

    case dict[:"$initial_call"] do
      {mod, _f, _a} ->
        identify_gl_module(pid, mod)

      nil ->
        :noop
    end

    {:current_stacktrace, stacktrace} = Process.info(pid, :current_stacktrace)

    for {mod, _fun, _arg, _loc} <- stacktrace do
      identify_gl_module(pid, mod)
    end

    {:error, :unknown_type}
  catch
    {:ok, _type} = result ->
      result

    {:error, _err} = result ->
      result
  end

  defp identify_gl_module(gl, mod) do
    case mod do
      :application_master ->
        ms =
          fn {{:application_master, app}, ^gl} -> app end
          |> :ets.fun2ms()

        {[app], _cont} = :ets.select(:ac_tab, ms, 1)

        throw({:ok, {:application, app, gl}})

      Leader ->
        {:ok, %Leader{group_leader: pid, ets_table_id: tid}} = Leader.get_group_data(gl)
        throw({:ok, {:group, pid, tid, gl}})

      :user ->
        throw({:ok, {:shell, gl}})

      StringIO ->
        throw({:ok, {:capture_io, gl}})

      :group ->
        throw({:ok, {:shell, gl}})

      _ ->
        :noop
    end
  end
end
