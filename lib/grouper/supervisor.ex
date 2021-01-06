defmodule Grouper.Supervisor do
  use Supervisor

  @doc """
  Starts application-level supervisor for Grouper.
  """
  @spec start_link(keyword(), keyword()) :: Supervisor.on_start()
  def start_link(init_opts \\ [], opts \\ [name: __MODULE__]) do
    Supervisor.start_link(__MODULE__, init_opts, opts)
  end

  @spec init(keyword) :: {:ok, {:supervisor.sup_flags(), [:supervisor.child_spec()]}} | :ignore
  @doc false
  @impl true
  def init(opts) do
    children = [Grouper.Group.Reaper]

    opts = Keyword.put_new(opts, :strategy, :one_for_one)

    :grouper_global_tab = :ets.new(:grouper_global_tab, [:named_table, :set, :public])

    Supervisor.init(children, opts)
  end
end
