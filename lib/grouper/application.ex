defmodule Grouper.Application do
  @moduledoc """
  application for Grouper

  This starts up an application supervisor that manages global tables and
  metadata used to drive groups.
  """
  use Application

  @impl true
  def start(_type, _args) do
    Grouper.Supervisor.start_link()
  end
end
