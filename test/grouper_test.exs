defmodule GrouperTest do
  use ExUnit.Case, async: true
  doctest Grouper

  test "group static start / stop" do
    assert {:ok, gl_pid} = Grouper.start_link()
    assert Process.alive?(gl_pid)
    assert {:ok, []} = Grouper.Config.get_all()
    assert :ok = Grouper.stop()
    assert not Process.alive?(gl_pid)
  end

  test "group exec with anon func" do
    {:ok, {:ok, []}} = Grouper.exec(fn -> Grouper.Config.get_all() end)
    {:ok, []} = Grouper.exec!(fn -> Grouper.Config.get_all() end)
  end

  test "group exec with mfa" do
    {:ok, {:ok, []}} = Grouper.exec(GrouperTest.Utils, :do_enum, [:param])
    {:ok, []} = Grouper.exec!(GrouperTest.Utils, :do_enum, [:param])
  end

  test "group func with no group (should fail)" do
    # this relies on the fact that tests don't run in an app
    {:error, :no_group} = Grouper.Config.get_all()
  end
end
