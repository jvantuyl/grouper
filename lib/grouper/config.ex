defmodule Grouper.Config do
  @moduledoc """
  configuration functionality for groups
  """
  alias Grouper.Group.Data

  def get_all() do
    Data.enum(:config)
  end

  def get(key) do
    Data.get(:config, key)
  end

  def put(key, val) do
    Data.put(:config, key, val)
  end
end
