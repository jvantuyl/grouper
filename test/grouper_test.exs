defmodule GrouperTest do
  use ExUnit.Case, async: true
  doctest Grouper

  test "group func with no group or app (should fail)" do
    # should detect user as group leader
    assert {:ok, {:user, nil, _pid}} = Grouper.Ident.identify_group_leader()

    assert {:error, :no_group} = Grouper.Config.get_all()

    # should detect a weird group leader due to IO capture in tests
    ExUnit.CaptureIO.capture_io(fn ->
      assert {:error, :no_group} = Grouper.Config.get_all()
    end)
  end

  test "group static start / stop" do
    assert {:ok, gl_pid} = Grouper.start_link()
    assert Process.alive?(gl_pid)

    assert {:ok, []} = Grouper.Config.get_all()

    assert :ok = Grouper.stop()
    assert not Process.alive?(gl_pid)
  end

  test "group exec with anon func" do
    anon_func = fn ->
      Grouper.Config.put(:foo, :bar)
      Grouper.Config.put(:testing, [1, 2, 3])
      {:ok, configs} = Grouper.Config.get_all()
      Enum.sort(configs)
    end

    result = [
      foo: :bar,
      testing: [1, 2, 3]
    ]

    assert {:ok, ^result} = Grouper.exec(anon_func)
    assert ^result = Grouper.exec!(anon_func)
  end

  test "group exec with mfa" do
    result = [param: true]

    assert {:ok, ^result} = Grouper.exec(GrouperTest.Utils, :do_enum, [:param])
    assert ^result = Grouper.exec!(GrouperTest.Utils, :do_enum, [:param])
  end

  test "app static with config" do
    # code_server runs under the kernel app
    cs_pid = Process.whereis(:code_server)
    {:group_leader, kernel_gl} = Process.info(cs_pid, :group_leader)
    kernel_config = Application.get_all_env(:kernel)

    # save original leader
    orig_gl = Process.group_leader()

    try do
      # briefly set ourselves to run under the kernel app
      true = Process.group_leader(self(), kernel_gl)

      assert {:ok, {:application, :kernel, _pid}} = Grouper.Ident.identify_group_leader(kernel_gl)
      # should automatically load OTP env
      assert {:ok, result} = Grouper.Config.get_all()
      assert Enum.sort(result) == Enum.sort(kernel_config)
    after
      # always restore old leader afterwards
      true = Process.group_leader(self(), orig_gl)
    end
  end

  test "group config set / unset"
  test "non-app OTP force load"
  test "app OTP suppress load"

  test "grouper naming registry"
end
