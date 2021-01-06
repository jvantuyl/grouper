defmodule Grouper.Group.Leader do
  @moduledoc """
  This implements a group leader capable of IO and storing group metadata.

  A `Grouper.Group.Leader` forwards IO upstream, just like any other
  group_leader. In addition, it also allocates a ETS table for this group and
  registers it in a global ETS table.

  Requests for configuration and naming functions (mediated by the
  `Grouper.Group.Data` module) store information in this ETS table (among
  other places).
  """

  use GenServer

  @init_opts [:leader, :commandeer, :parent]

  defstruct [:self, :group_leader, :commandeered, :ets_table_id]

  @typedoc "state for Grouper.Leader"
  @type t() :: %__MODULE__{}

  @typedoc "options to start function"
  @type options() :: [option()]

  @typedoc "options to init function"
  @type init_options() :: [init_option()]

  @typedoc "keyword options for start function"
  @type option() :: GenServer.option() | init_option()

  @typedoc "keyword options for init function"
  @type init_option() ::
          {:commandeer, boolean() | pid() | [pid()]}
          | {:leader, pid()}
          | {:parent, pid()}

  @typedoc "valid info terms"
  @type infos() :: io_request()

  @typedoc "IO request info term"
  @type io_request() :: {:io_request, pid(), any(), any()}

  # API

  @doc """
  Starts a Grouper.Leader process linked to the current process.

  This is typically used in a supervision tree.

  In addition to the normal options accepted by GenServer.start_link/3, this
  also accepts the following options:

    * `commandeer` - during initialization, sets itself as group_leader for
      this process or list of processes instead of the calling process

    * `leader` - during initialization, sets this process as the group_leader
      to which it forwards IO requests

    * `parent` - this specifies the parent process, useful for testing and when
                 not being started in a normal supervision tree
  """
  @spec start_link(options()) :: GenServer.on_start()
  def start_link(opts \\ []) when is_list(opts) do
    {init_opts, start_link_opts} = Keyword.split(opts, @init_opts)
    GenServer.start_link(__MODULE__, init_opts, start_link_opts)
  end

  @spec get_group_data(pid()) :: {:ok, t()}
  def get_group_data(glpid) do
    case :ets.lookup(:grouper_global_tab, {:group, glpid}) do
      [{_key, state}] ->
        {:ok, state}

      [] ->
        {:error, :not_found}
    end
  end

  def get_group_leader(glpid) do
    GenServer.call(glpid, :get_group_leader)
  end

  def stop(glpid, reason \\ :normal) do
    GenServer.stop(glpid, reason)
  end

  # GenServer callbacks

  @doc false
  @impl true
  @spec init(init_options()) :: {:ok, t()} | {:stop, :no_parent}
  def init(opts) when is_list(opts) do
    my_group_leader = Keyword.get_lazy(opts, :leader, &Process.group_leader/0)

    Process.flag(:trap_exit, true)

    commandeered =
      case Keyword.get(opts, :commandeer, false) do
        pid when is_pid(pid) ->
          Process.group_leader(pid, self())
          [pid]

        pids when is_list(pids) ->
          for pid <- pids do
            Process.group_leader(pid, self())
            pid
          end

        true ->
          parent = get_parent(opts)
          true = Process.group_leader(parent, self())
          [parent]

        false ->
          []
      end

    uid = :erlang.unique_integer([:positive])
    tid = :ets.new(:"grouper_group_#{uid}_tab", [:set, :public])

    state = %__MODULE__{
      self: self(),
      group_leader: my_group_leader,
      commandeered: commandeered,
      ets_table_id: tid
    }

    true = :ets.insert(:grouper_global_tab, {{:group, self()}, state})

    {:ok, state}
  catch
    {:error, reason} ->
      {:stop, reason}
  end

  @doc false
  @impl true
  def handle_call(:get_group_leader, _from, %__MODULE__{} = state) do
    {:reply, state.group_leader, state}
  end

  @doc false
  @impl true
  @spec handle_info(infos(), t()) :: {:noreply, t()}
  def handle_info({:io_request, _from, _reply_as, _request} = io_request, %__MODULE__{} = state) do
    send(state.group_leader, io_request)
    {:noreply, state}
  end

  @doc false
  @impl true
  def terminate(_reason, %__MODULE__{} = state) do
    # restore commandeered processes' group leaders
    for pid <- state.commandeered do
      try do
        Process.group_leader(pid, state.group_leader)
      rescue
        ArgumentError ->
          # happens when one of the pids has already exited
          :ok
      end
    end

    # delete ETS table
    true = :ets.delete(:grouper_global_tab, {:group, state.group_leader})

    :ignored
  end

  # TODO: trap_exits and re-parent processes to application master during shutdown
  #       if feasible, not sure on efficiency of walking entire process space

  # internal helper functions

  defp get_parent(opts) do
    ancestors = Process.get(:"$ancestors")
    parent = Keyword.get(opts, :parent)

    case {parent, ancestors} do
      {parent, _} when is_pid(parent) ->
        parent

      {_, nil} ->
        exit(:no_parent)

      {_, []} ->
        exit(:no_parent)

      {_, [parent | _]} when is_pid(parent) ->
        parent
    end
  end
end
