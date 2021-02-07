defmodule Grouper.Data.Group do
  @moduledoc """
  data layer driver for explicitly-created groups
  """
  require Ex2ms

  @type group_pid :: pid()
  @type group_tid :: atom()
  @type meta :: {group_pid(), group_tid()}

  @type type :: Grouper.Data.type()
  @type key :: Grouper.Data.key()
  @type value :: Grouper.Data.value()

  @doc """
  enumerates all key-values of a given type

  Specify the special type `:_` to read data of all types
  """
  @spec enum(meta(), type()) :: [{{type(), key()}, value()}] | [{key(), value()}]
  def enum({pid, tid}, type) do
    ms =
      case type do
        :_ ->
          Ex2ms.fun do
            {{type, {:group, ^pid}, key}, val} -> {{type, key}, val}
          end

        _ ->
          Ex2ms.fun do
            {{^type, {:group, ^pid}, key}, val} -> {key, val}
          end
      end

    :ets.select(tid, ms)
  end

  @doc """
  get data value of a given type and a given key
  """
  @spec get(meta(), type(), key()) :: value() | nil
  def get({pid, tid}, type, key) do
    case :ets.lookup(tid, {type, {:group, pid}, key}) do
      [{_, val}] ->
        val

      [] ->
        nil
    end
  end

  @doc """
  store data value of a given type and a given key
  """
  @spec put(meta(), type(), key(), value()) :: value() | nil
  def put({pid, tid} = meta, type, key, val) do
    # this is not atomic, but if you're racing on this data, you've got bigger problems
    orig_val = get(meta, type, key)
    true = :ets.insert(tid, {{type, {:group, pid}, key}, val})
    orig_val
  end

  @doc """
  delete data value of a given type and a given key
  """
  @spec del(meta(), type(), key()) :: value() | nil
  def del({pid, tid} = meta, type, key) do
    # this is not atomic, but if you're racing on this data, you've got bigger problems
    orig_val = get(meta, type, key)
    true = :ets.delete(tid, {type, {:group, pid}, key})
    orig_val
  end

  @doc """
  initialize group-driven data

  Currently does nothing.
  """
  @spec init(meta(), opts :: keyword()) :: :ok
  def init(_meta, _opts) do
    # no initialization for groups
    :ok
  end
end
