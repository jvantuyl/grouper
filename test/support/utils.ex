defmodule GrouperTest.Utils do
  def do_enum(:param) do
    Grouper.Config.get_all()
  end
end
