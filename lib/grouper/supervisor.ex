defmodule Grouper.Supervisor do
  @moduledoc """
  supervisor process for `Grouper` application
  """
  use Supervisor

  # === API ===

  @doc """
  Starts application-level supervisor for Grouper.

  Maintains global information that drives groups.
  """
  @spec start_link(keyword(), keyword()) :: Supervisor.on_start()
  def start_link(init_opts \\ [], opts \\ [name: __MODULE__]) do
    Supervisor.start_link(__MODULE__, init_opts, opts)
  end

  # === Supervisor Callbacks ===

  @spec init(keyword) :: {:ok, {:supervisor.sup_flags(), [:supervisor.child_spec()]}} | :ignore
  @doc false
  @impl true
  def init(opts) do
    children = [Grouper.Reaper]

    opts = Keyword.put_new(opts, :strategy, :one_for_one)

    :grouper_global_tab = :ets.new(:grouper_global_tab, [:named_table, :set, :public])

    Supervisor.init(children, opts)
  end
end
