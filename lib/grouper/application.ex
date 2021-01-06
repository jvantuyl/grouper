defmodule Grouper.Application do
  @moduledoc """
  """
  use Application

  def start(_type, _args) do
    Grouper.Supervisor.start_link()
  end
end
