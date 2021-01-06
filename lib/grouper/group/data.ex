defmodule Grouper.Group.Data do
  @moduledoc """
  """
  require Ex2ms

  defstruct [:enum, :get, :put, :del, :group_leader]

  # API

  def enum(type, opts \\ []) when is_list(opts) do
    case api(opts) do
      {:ok, %__MODULE__{enum: enum_func}} ->
        {:ok, enum_func.(type)}

      {:error, _err} = err ->
        err
    end
  end

  def get(type, key, opts \\ []) when is_list(opts) do
    case api(opts) do
      {:ok, %__MODULE__{get: get_func}} ->
        {:ok, get_func.(type, key)}

      {:error, _err} = err ->
        err
    end
  end

  def put(type, key, val, opts \\ []) when is_list(opts) do
    case api(opts) do
      {:ok, %__MODULE__{put: put_func}} ->
        {:ok, put_func.(type, key, val)}

      {:error, _err} = err ->
        err
    end
  end

  def del(type, key, opts \\ []) when is_list(opts) do
    case api(opts) do
      {:ok, %__MODULE__{del: del_func}} ->
        {:ok, del_func.(type, key)}

      {:error, _err} = err ->
        err
    end
  end

  # helper functions

  defp api(opts) when is_list(opts) do
    no_leader = make_ref()

    gl_opt = Keyword.get(opts, :leader, no_leader)

    # API will be chosen among (in descending order of preference):
    # - API constructed from explictly given pid or atom
    # - cached API when no leader is given and a cached copy exists
    # - construct API for current process' group leader
    gl =
      cond do
        is_nil(gl_opt) ->
          raise ArgumentError, "group leader must be pid or atom, not (nil)"

        is_pid(gl_opt) or is_atom(gl_opt) ->
          gl_opt

        gl_opt == no_leader ->
          group_leader = Process.group_leader()

          if match?(%__MODULE__{group_leader: ^group_leader}, api = Process.get(:grouper_api)) do
            throw({:ok, api})
          end

          group_leader

        true ->
          raise ArgumentError, "group leader must be pid or atom, not (#{inspect(gl_opt)})"
      end

    case Grouper.Ident.identify_group_leader(gl) do
      {:error, :dead} ->
        {:error, :no_group}

      {:error, :unknown_type} ->
        {:error, :no_group}

      {:ok, {:shell, ^gl}} ->
        {:error, :no_group}

      {:ok, {:user, ^gl}} ->
        {:error, :no_group}

      {:ok, {:capture_io, ^gl}} ->
        {:error, :no_group}

      {:ok, {:application, app_name, ^gl}} ->
        new_api = %__MODULE__{
          enum: &app_enum(app_name, &1),
          get: &app_get(app_name, &1, &2),
          put: &app_put(app_name, &1, &2, &3),
          del: &app_del(app_name, &1, &2),
          group_leader: gl
        }

        # cache it, but only if we looked up our own group leader
        if gl == Process.group_leader(), do: Process.put(:grouper_api, new_api)

        {:ok, new_api}

      {:ok, {:group, group_leader, ets_tid, ^gl}} ->
        new_api = %__MODULE__{
          enum: &group_enum(group_leader, ets_tid, &1),
          get: &group_get(group_leader, ets_tid, &1, &2),
          put: &group_put(group_leader, ets_tid, &1, &2, &3),
          del: &group_del(group_leader, ets_tid, &1, &2),
          group_leader: gl
        }

        # cache it, but only if we looked up our own group leader
        if gl == Process.group_leader(), do: Process.put(:grouper_api, new_api)

        {:ok, new_api}
    end
  catch
    {:ok, _api} = result ->
      result
  end

  defp app_enum(app_name, type) do
    ms =
      case type do
        :_ ->
          Ex2ms.fun do
            {{type, {:app, ^app_name}, key}, val} -> {{type, key}, val}
          end

        _ ->
          Ex2ms.fun do
            {{^type, {:app, ^app_name}, key}, val} -> {key, val}
          end
      end

    :ets.select(:grouper_global_tab, ms)
  end

  defp app_get(app_name, type, key) do
    case :ets.lookup(:grouper_global_tab, {type, {:app, app_name}, key}) do
      [val] ->
        val

      [] ->
        nil
    end
  end

  defp app_put(app_name, type, key, val) do
    # this is not atomic, but if you're racing on this data, you've got bigger problems
    orig_val = app_get(app_name, type, key)
    true = :ets.insert(:grouper_global_tab, {{type, {:app, app_name}, key}, val})
    orig_val
  end

  defp app_del(app_name, type, key) do
    # this is not atomic, but if you're racing on this data, you've got bigger problems
    orig_val = app_get(app_name, type, key)
    true = :ets.delete(:grouper_global_tab, {type, {:app, app_name}, key})
    orig_val
  end

  defp group_enum(group_pid, tid, type) do
    ms =
      case type do
        :_ ->
          Ex2ms.fun do
            {{type, {:group, ^group_pid}, key}, val} -> {{type, key}, val}
          end

        _ ->
          Ex2ms.fun do
            {{^type, {:group, ^group_pid}, key}, val} -> {key, val}
          end
      end

    :ets.select(tid, ms)
  end

  defp group_get(group_pid, tid, type, key) do
    case :ets.lookup(tid, {type, {:group, group_pid}, key}) do
      [{_, val}] ->
        val

      [] ->
        nil
    end
  end

  defp group_put(group_pid, tid, type, key, val) do
    # this is not atomic, but if you're racing on this data, you've got bigger problems
    orig_val = group_get(group_pid, tid, type, key)
    true = :ets.insert(tid, {{type, {:group, group_pid}, key}, val})
    orig_val
  end

  defp group_del(group_pid, tid, type, key) do
    # this is not atomic, but if you're racing on this data, you've got bigger problems
    orig_val = group_get(group_pid, tid, type, key)
    true = :ets.delete(tid, {type, {:group, group_pid}, key})
    orig_val
  end
end
