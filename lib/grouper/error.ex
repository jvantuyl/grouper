defmodule Grouper.NoGroupError do
  defexception []

  def message(exc) do
    "failure locating group data"
  end
end
