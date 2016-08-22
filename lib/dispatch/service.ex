defmodule Dispatch.Service do

  alias Dispatch.Registry

  def init(opts) do
    type = Keyword.fetch!(opts, :type)
    case Registry.add_service(type, self) do
      {:ok, _} -> :ok
      other -> other
    end
  end

  def cast(type, key, params) do
    case Registry.get_service_pid(type, key) do
      {:ok, _node, pid} -> GenServer.cast(pid, params)
      _ -> {:error, :service_unavailable}
    end
  end

  def call(type, key, params, timeout \\ 5000) do
    case Registry.get_service_pid(type, key) do
      {:ok, _node, pid} -> GenServer.call(pid, params, timeout)
      _ -> {:error, :service_unavailable}
    end
  end

  def multi_cast(count, type, key, params) do
    case Registry.get_service_many_pids(count, type, key) do
      [] -> {:error, :service_unavailable}
      servers -> 
        servers
        |> Enum.each(fn ({_node, pid}) ->
          GenServer.cast(pid, params)
        end)
        {:ok, Enum.count(servers)}
    end
  end

  def multi_call(count, type, key, params, timeout \\ 5000) do
    case Registry.get_service_many_pids(count, type, key) do
      [] -> {:error, :service_unavailable}
      servers -> 
        parent = self
        for {_node, pid} <- servers do
          Task.async(fn ->
            {pid, GenServer.call(pid, params, timeout)}
            # Process.unlink(parent)
          end)
        end |> Enum.map(&Task.await(&1, :infinity))
    end
  end


end
