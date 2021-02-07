defmodule Grouper.Data do
  @moduledoc """
  uniform data layer for groups of processes
  """
  require Ex2ms
  alias Grouper.Ident
  alias Grouper.Data.App
  alias Grouper.Data.Group

  @type opts :: keyword()
  @type type() :: atom()
  @type key() :: any()
  @type value() :: any()

  @type t :: %__MODULE__{
          enum: (type() -> [{{type(), key()}, value()}] | [{key(), value()}]),
          get: (type(), key() -> value() | nil),
          put: (type(), key(), value() -> value() | nil),
          del: (type(), key() -> value() | nil),
          group_leader: atom() | pid()
        }
  defstruct [:enum, :get, :put, :del, :group_leader]

  # === API ===

  @doc """
  enumerates all key-values of a given data type

  Specify the special type `:_` to read data of all types
  """
  @spec enum(type(), opts()) ::
          {:ok, [{{type(), key()}, value()}] | [{key(), value()}]} | {:error, :no_group}
  def enum(type, opts \\ []) when is_list(opts) do
    case api(opts) do
      {:ok, %__MODULE__{enum: enum_func}} ->
        {:ok, enum_func.(type)}

      {:error, _err} = err ->
        err
    end
  end

  @doc """
  get data value of a given type and a given key
  """
  @spec get(type(), key(), opts()) :: {:ok, value() | nil} | {:error, :no_group}
  def get(type, key, opts \\ []) when is_list(opts) do
    case api(opts) do
      {:ok, %__MODULE__{get: get_func}} ->
        {:ok, get_func.(type, key)}

      {:error, _err} = err ->
        err
    end
  end

  @doc """
  store data value of a given type and a given key
  """
  @spec put(type(), key(), value(), opts()) :: {:ok, value() | nil} | {:error, :no_group}
  def put(type, key, val, opts \\ []) when is_list(opts) do
    case api(opts) do
      {:ok, %__MODULE__{put: put_func}} ->
        {:ok, put_func.(type, key, val)}

      {:error, _err} = err ->
        err
    end
  end

  @doc """
  delete data value of a given type and a given key
  """
  @spec del(type(), key(), opts()) :: {:ok, value() | nil} | {:error, :no_group}
  def del(type, key, opts \\ []) when is_list(opts) do
    case api(opts) do
      {:ok, %__MODULE__{del: del_func}} ->
        {:ok, del_func.(type, key)}

      {:error, _err} = err ->
        err
    end
  end

  @doc """
  identifies which type of group is being used, builds API functions, and
  caches them in the process dictionary

  ## Options

  - `:leader` - override detected group leader with specified one (mostly
                used in testing)
  """
  @spec api(opts()) :: {:ok, t()} | {:error, :no_group}
  def api(opts) when is_list(opts) do
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

    case Ident.identify_group_leader(gl) do
      {:error, :dead} ->
        {:error, :no_group}

      {:error, :unknown_type} ->
        {:error, :no_group}

      {:ok, {mod, nil, ^gl}} when mod in [:shell, :user, :capture_io] ->
        {:error, :no_group}

      {:ok, {mod, meta, ^gl}} when mod in [:application, :group] ->
        impl =
          case mod do
            :application -> App
            :group -> Group
          end

        new_api = %__MODULE__{
          enum: &impl.enum(meta, &1),
          get: &impl.get(meta, &1, &2),
          put: &impl.put(meta, &1, &2, &3),
          del: &impl.del(meta, &1, &2),
          group_leader: gl
        }

        :ok = impl.init(meta, opts)

        # cache it, but only if we looked up our own group leader
        if gl == Process.group_leader(), do: Process.put(:grouper_api, new_api)

        {:ok, new_api}
    end
  catch
    {:ok, _api} = result ->
      result
  end
end
