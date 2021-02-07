defmodule Grouper.Data.App do
  @moduledoc """
  data layer driver for `:application` implied groups
  """
  require Ex2ms

  @type app_name() :: atom()
  @type meta() :: app_name()

  @type type :: Grouper.Data.type()
  @type key :: Grouper.Data.key()
  @type value :: Grouper.Data.value()

  @doc """
  enumerates all key-values of a given type

  Specify the special type `:_` to read data of all types
  """
  @spec enum(meta(), type()) :: [{{type(), key()}, value()}] | [{key(), value()}]
  def enum(app_name, type) do
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

  @doc """
  get data value of a given type and a given key
  """
  @spec get(meta(), type(), key()) :: value() | nil
  def get(app_name, type, key) do
    case :ets.lookup(:grouper_global_tab, {type, {:app, app_name}, key}) do
      [val] ->
        val

      [] ->
        nil
    end
  end

  @doc """
  store data value of a given type and a given key
  """
  @spec put(meta(), type(), key(), value()) :: value() | nil
  def put(app_name, type, key, val) do
    # this is not atomic, but if you're racing on this data, you've got bigger problems
    orig_val = get(app_name, type, key)
    true = :ets.insert(:grouper_global_tab, {{type, {:app, app_name}, key}, val})
    orig_val
  end

  @doc """
  delete data value of a given type and a given key
  """
  @spec del(meta(), type(), key()) :: value() | nil
  def del(app_name, type, key) do
    # this is not atomic, but if you're racing on this data, you've got bigger problems
    orig_val = get(app_name, type, key)
    true = :ets.delete(:grouper_global_tab, {type, {:app, app_name}, key})
    orig_val
  end

  @doc """
  initialize application-driven data

  This may load OTP environment data. It only attempts to either load or
  suppress loading the first time it's called. Given that loading is the
  default, it is necessary to suppress loading the environment very early in
  application loading if this is desired.

  ## Options

  - load_otp_env: Set to `true` to load the current application's environment
    (the default), to an atom to load a specific applications environment, or
    to `false` to suppress loading any environment.
  """
  @spec init(meta(), opts :: keyword()) :: :ok
  def init(app_name = meta, opts) when is_atom(app_name) and is_list(opts) do
    # load legacy config if we haven't already
    case :ets.lookup(:grouper_global_tab, {:app_initialized, app_name}) do
      [{{:app_initialized, ^app_name}, true}] ->
        :ok

      [] ->
        :ets.insert(:grouper_global_tab, {{:app_initialized, app_name}, true})

        # don't load config if asked not to
        case Keyword.get(opts, :load_otp_env, true) do
          false ->
            :noop

          true ->
            for {k, v} <- Application.get_all_env(app_name) do
              put(meta, :config, k, v)
            end

          load_app when is_atom(load_app) ->
            # For those rare times when you want to load one application's env
            # as another application's config.
            #
            # NOTE: If anybody ever uses this, let me know. I have no idea what
            # use case would benefit from this.
            for {k, v} <- Application.get_all_env(load_app) do
              put(meta, :config, k, v)
            end
        end

        :ok
    end
  end
end
