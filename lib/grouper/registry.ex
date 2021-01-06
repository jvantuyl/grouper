defmodule Grouper.Registry do
  alias Grouper.Group.Data

  def register_name(name, pid) do
    case whereis_name(name) do
      :undefined ->
        case Data.put(:registered_name, name, pid) do
          {:ok, _} ->
            :yes

          {:error, reason} ->
            raise RuntimeError, reason: reason
        end

      pid when is_pid(pid) ->
        :no
    end
  end

  def unregister_name(name) do
    case Data.del(:registered_name, name) do
      {:ok, _pid} ->
        :ok

      {:error, reason} ->
        raise RuntimeError, reason: reason
    end
  end

  def whereis_name(name) do
    case Data.get(:registered_name, name) do
      {:ok, pid} when is_pid(pid) ->
        # check liveness because we do lazy reaping
        if Process.alive?(pid) do
          pid
        else
          :undefined
        end

      {:ok, nil} ->
        :undefined

      {:error, reason} ->
        raise RuntimeError, reason: reason
    end
  end

  def send(name, msg) do
    case Data.get(:registered_name, name) do
      {:ok, pid} when is_pid(pid) ->
        Kernel.send(pid, msg)

      {:ok, nil} ->
        exit({:badarg, {name, msg}})

      {:error, reason} ->
        raise RuntimeError, reason: reason
    end
  end
end
