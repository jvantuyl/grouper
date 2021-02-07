defmodule Grouper.Ident do
  @moduledoc """
  Functions for identifying group leader types.
  """
  @compile {:inline, identify_gl_module: 2}

  require Ex2ms

  alias Grouper.GroupLeader

  @typedoc "type of group leader process"
  @type leader_spec() ::
          app_leader() | grouper_leader() | capture_io_leader() | shell_leader() | user_leader()

  @type app_leader :: {:application, app_meta(), pid()}
  @type app_meta :: Application.app()

  @type grouper_leader :: {:group, grouper_meta(), pid()}
  @type grouper_meta :: {pid(), :ets.tab()}

  @type capture_io_leader :: {:capture_io, capture_io_meta(), pid()}
  @type capture_io_meta :: nil

  @type shell_leader :: {:shell, shell_meta(), pid()}
  @type shell_meta :: nil

  @type user_leader :: {:user, user_meta(), pid()}
  @type user_meta :: nil

  @typedoc "possible errors identifying group leaders"
  @type group_leader_errors() :: :dead | :unknown_type

  @doc """
  Identifies the type of group leader for current process.
  """
  @spec identify_group_leader() :: {:ok, leader_spec()} | {:error, group_leader_errors()}
  def identify_group_leader() do
    Process.group_leader()
    |> identify_group_leader()
  end

  @doc """
  Identifies the type of group leader by its pid.
  """
  @spec identify_group_leader(pid()) ::
          {:ok, leader_spec()} | {:error, group_leader_errors()}
  def identify_group_leader(pid) when is_pid(pid) do
    if not Process.alive?(pid) do
      throw({:error, :dead})
    end

    if pid == Process.whereis(:user) do
      throw({:ok, {:user, nil, pid}})
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
    {:ok, {_mod, _meta, ^pid}} = result ->
      result

    {:error, _err} = result ->
      result
  end

  defp identify_gl_module(gl, mod) do
    case mod do
      :application_master ->
        ms =
          Ex2ms.fun do
            {{:application_master, app}, ^gl} -> app
          end

        {[app], _cont} = :ets.select(:ac_tab, ms, 1)

        throw({:ok, {:application, app, gl}})

      GroupLeader ->
        {:ok, %GroupLeader{group_leader: pid, ets_table_id: tid}} = GroupLeader.get_group_data(gl)
        throw({:ok, {:group, {pid, tid}, gl}})

      :user ->
        throw({:ok, {:shell, nil, gl}})

      StringIO ->
        throw({:ok, {:capture_io, nil, gl}})

      :group ->
        throw({:ok, {:shell, nil, gl}})

      _ ->
        :noop
    end
  end
end
