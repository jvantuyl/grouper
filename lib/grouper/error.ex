defmodule Grouper.NoGroupError do
  @moduledoc """
  no group error

  Used by immediate-mode (i.e. !-suffixed) versions of functions.
  """
  defexception []

  def message(_exc) do
    "failure locating group data"
  end
end
