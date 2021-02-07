defmodule Grouper.Config do
  @moduledoc """
  configuration functionality for groups
  """
  alias Grouper.Data

  @doc """
  Used to load a specific application's environment. Not needed when running
  under an application, but useful for scripts and tests.

  NOTE: Will not load the environment if it's already been loaded or
        suppressed.
  """
  @spec load_otp_env(Application.app(), Data.opts()) :: :ok
  def load_otp_env(app \\ true, opts \\ []) when is_atom(app) do
    Data.enum(:config, [{:load_otp_env, app} | opts])

    :ok
  end

  @doc """
  Used when running under an application to suppress loading the application
  config.

  NOTE: Will not suppress loading the environment if it's already been
        loaded. Must be called before anything attempts to read config to be
        effective.
  """
  @spec suppress_otp_env(Data.opts()) :: :ok
  def suppress_otp_env(opts \\ []) do
    Data.enum(:config, [{:load_otp_env, false} | opts])

    :ok
  end

  @doc """
  get all configuration as a keyword list
  """
  @spec get_all(keyword()) :: {:ok, Data.opts()} | {:error, :no_group}
  def get_all(opts \\ []) do
    Data.enum(:config, opts)
  end

  @doc """
  get configuration for a given key
  """
  @spec get(Data.key(), Data.opts()) :: {:ok, Data.value()} | {:error, :no_group}
  def get(key, opts \\ []) do
    Data.get(:config, key, opts)
  end

  @doc """
  set configuration for a given key to a value
  """
  @spec put(Data.key(), Data.value(), Data.opts()) :: {:ok, Data.value} | {:error, :no_group}
  def put(key, val, opts \\ []) do
    Data.put(:config, key, val, opts)
  end

  @doc """
  delete configuration for a given key
  """
  @spec del(Data.key(), Data.opts()) :: {:ok, Data.value()} | {:error, :no_group}
  def del(key, opts \\ []) do
    Data.del(:config, key, opts)
  end
end
