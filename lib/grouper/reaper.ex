defmodule Grouper.Reaper do
  @moduledoc """
  Reaps metadata for defunct groups and registered names.
  """
  use GenServer

  require Ex2ms
  require Logger

  alias Grouper.Data

  # === API ===

  @doc """
  starts reaper
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  # === GenServer Callbacks ===

  @impl true
  def init([]) do
    :timer.send_interval(60_000, :reap)
  end

  @impl true
  def handle_info(:reap, state) do
    ms =
      Ex2ms.fun do
        {{:group, pid}, _} when is_pid(pid) -> pid
      end

    for glpid <- :ets.select(:grouper_global_tab, ms) do
      if Process.alive?(glpid) do
        {:ok, names} = Data.enum(:registered_name, leader: glpid)

        for {name, pid} <- names do
          if not Process.alive?(pid) do
            # Logger.info("reaping dead Grouper.Registry registed name (#{name} -> #{inspect(pid)})")
            Data.del(:registered_name, name, leader: glpid)
          end
        end
      else
        Logger.info("reaping dead Group metadata (leader=#{inspect(glpid)})")
        # no need to delete its ETS table, it should've died with the leader itself
        true = :ets.delete(:grouper_global_tab, {:group, glpid})
      end
    end

    {:noreply, state}
  end
end
