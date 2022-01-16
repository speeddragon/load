defmodule Load.Runner do
  use GenServer

  require Logger

  # @default_max_sleep_time_ms 200

  def start_link(args), do: GenServer.start_link(__MODULE__, args, name: __MODULE__)

  def init(_config) do
    # :erlang.process_flag(:trap_exit, true)
    # Logger.info("runner init #{inspect(config)}")
    # Load.Stats.init()

    # :ets.new(:running_workers, [:named_table, :public, :bag])

    # config |> setup_nodes() |> setup_workers()

    # Process.send_after(self(), :print_stats, :timer.seconds(10))

    # # Make sleep time 10% shorter to compensate for timers latency but min 1ms
    # sleep_ms = max(1, Map.get(config, :sleep_time_ms, @default_max_sleep_time_ms) * 9 / 10)

    # state = %{
    #   sleep_ms: sleep_ms,
    #   config: config
    # }
    # print_usage()
    state = %{}
    {:ok, state}
  end

  # TABS :running_workers :active_nodes

  def add(node_id \\ :all, count) when is_integer(count) and count > 0 and (node_id == :all or is_binary(node_id)), do:
    GenServer.call(__MODULE__, {:add, node_id, count})

  def remove(node_id \\ :all, count) when is_integer(count) and count > 0 and (node_id == :all or is_binary(node_id)), do:
    GenServer.call(__MODULE__, {:remove, node_id, count})

  def stop do
    :ets.tab2list(:running_workers)
    |> Enum.each(fn {k, pid} ->
      send(pid, :stop)
      :ets.delete_object(:running_workers, {k, pid})
    end)
  end

  def on_worker_started(node_id, pid) do
    Logger.info("[Load] worker #{node_id}/#{pid} started")
    :ets.insert(:running_workers, {node_id, pid})
  end


  def on_worker_terminated(node_id, pid, reason) do
    Logger.error("[Load] worker #{node_id}/#{pid} stopped for reason: #{reason}")
    ms = :ets.fun2ms(fn {_Node, p} -> p == pid end)
    :ets.select_delete(:running_workers, ms)
  end

  def handle_info({EXIT, pid, reason}, state) do
    Process.unlink(pid)
    on_worker_terminated(:unknown, pid, reason)
    {:noreply, state}
  end

  def handle_call({:add, node_id, count}, _from, state) do
    case node_id do
      :all -> :ets.tab2list(:active_nodes)
      _ -> :ets.lookup(:active_nodes, node_id)
    end
    |> Enum.each(fn {_node_id, node_config} ->
      create_workers_for_node(Map.put(node_config, :workers_per_node, count))
    end)
    {:reply, :ok2, state}
  end

  def handle_call({:remove, node_id, count}, _from, state) do
    case node_id do
      :all -> :ets.tab2list(:active_nodes)
      _ -> :ets.lookup(:active_nodes, node_id)
    end
    |> Enum.each(fn {node_id, _node_config} ->
      running_workers = :ets.lookup(:running_workers, node_id)
      if length(running_workers) > count do
        Enum.reduce(1..count, running_workers, fn (_n, [pid | more]) -> send(pid, :stop); more end)
        stop_workers(count, Enum.map(running_workers, &elem(&1, 1)))
      end
    end)
    {:reply, :ok2, state}
  end
  defp setup_nodes(config) do
    :ets.new(:active_nodes, [:named_table])

    Map.get(config, :load_nodes, [])
    |> Enum.each(fn node_config ->
      node_id = Map.get(node_config, :id)
      :ets.insert(:active_nodes, {node_id, node_config})
      Logger.info("Customer node (as map): #{inspect(Enum.into(node_config, %{}))}")
    end)

    config
  end

  defp setup_workers(config) do
    Map.get(config, :load_nodes, [])
    |> Enum.each(fn _ -> create_workers_for_node(config) end)

    config
  end


  defp create_workers_for_node(config) do

    pids = Enum.map(1..Map.get(config, :workers_per_node), fn _ ->
      # {:ok, pid} = Supervisor.start_child(:load_worker_sup, [configt])
      # Process.link(pid)
      # pid
      :ok
    end)

    node_id = config[:node_config].id
    count = length(pids)
    Logger.info("[#{__MODULE__}] spawned #{count} workers on node: #{node_id}")

    pids
  end

  defp stop_workers(count, running_workers), do:
    Enum.reduce(1..count, running_workers, fn (_n, [pid | more]) -> send(pid, :stop); more end)


  def print_usage() do
    IO.puts(
      "+-----------------------------------------------\n"
    <>"| Commands available:\n"
    <>"| Load.add   ('all'| node_id, workers) - increase workers for node_id or all\n"
    <>"| Load.remove('all'| node_id, workers) - reduce   workers for node_id or all\n"
    <>"| Load.stop() - <describe>\n"
    <>"| Load:i() - print current stats\n"
    <>"+-----------------------------------------------"
    )
  end

end
