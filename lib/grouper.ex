defmodule Grouper do
  @moduledoc """
  Documentation for `Grouper`.
  """

  defdelegate start_link(opts \\ []), to: Grouper.Group
  defdelegate stop(), to: Grouper.Group

  def exec(fun) do
    case Grouper.Group.start_link(commandeer: true) do
      {:ok, group_pid} ->
        group_pid

      {:error, _} = err ->
        throw(err)
    end

    try do
      {:ok, fun.()}
    after
      :ok = Grouper.Group.stop()
    end
  catch
    {:error, _} = err ->
      err
  end

  def exec!(fun) do
    case exec(fun) do
      {:ok, result} ->
        result

      {:error, :no_group} ->
        raise Grouper.NoGroupError

      {:error, reason} ->
        raise RuntimeError, reason: reason
    end
  end

  def exec(m, f, a) when is_atom(m) and is_atom(f) and is_list(a) do
    exec(fn -> apply(m, f, a) end)
  end

  def exec!(m, f, a) when is_atom(m) and is_atom(f) and is_list(a) do
    exec!(fn -> apply(m, f, a) end)
  end
end
