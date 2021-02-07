defmodule GrouperTest.Utils do
  def do_enum(param) do
    Grouper.Config.put(param, true)
    {:ok, all} = Grouper.Config.get_all()
    all
  end
end
