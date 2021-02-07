defmodule Grouper.Registry do
  @moduledoc """
  Provides name registration functions in the style of `:global` and
  `Registry`. Usually used with `GenServer.start_link/3` using `:via` option
  to provide an isolated namespace for various processes.
  """
  alias Grouper.Data

  @doc """
  registers a process under a name within a group

  ## Options

  Options are passed on to the underlying data layer. See `Data.api/1` for
  details.
  """
  @spec register_name(atom(), pid(), keyword()) :: :yes | :no | no_return()
  def register_name(name, pid, opts \\ []) do
    case whereis_name(name) do
      :undefined ->
        case Data.put(:registered_name, name, pid, opts) do
          {:ok, _} ->
            :yes

          {:error, reason} ->
            raise RuntimeError, reason: reason
        end

      pid when is_pid(pid) ->
        :no
    end
  end

  @doc """
  unregisters a process under a name within a group

  ## Options

  Options are passed on to the underlying data layer. See `Data.api/1` for
  details.
  """
  @spec unregister_name(atom(), keyword()) :: :ok | no_return()
  def unregister_name(name, opts \\ []) do
    case Data.del(:registered_name, name, opts) do
      {:ok, _pid} ->
        :ok

      {:error, reason} ->
        raise RuntimeError, reason: reason
    end
  end

  @doc """
  finds a process under a name within a group

  ## Options

  Options are passed on to the underlying data layer. See `Data.api/1` for
  details.
  """
  @spec whereis_name(atom(), keyword()) :: pid() | :undefined | no_return()
  def whereis_name(name, opts \\ []) do
    case Data.get(:registered_name, name, opts) do
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

  @doc """
  sends a message to a process under a name within a group

  ## Options

  Options are passed on to the underlying data layer. See `Data.api/1` for
  details.
  """
  @spec send(atom(), any(), keyword()) :: any()
  def send(name, msg, opts \\ []) do
    case Data.get(:registered_name, name, opts) do
      {:ok, pid} when is_pid(pid) ->
        Kernel.send(pid, msg)

      {:ok, nil} ->
        exit({:badarg, {name, msg}})

      {:error, reason} ->
        raise RuntimeError, reason: reason
    end
  end
end
