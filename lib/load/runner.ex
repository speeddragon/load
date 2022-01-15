defmodule Load.Runner do
  use GenServer

  require Logger


  @workers_tab :load_workers
  @nodes_tab :load_nodes
  @default_max_sleep_time_ms 200

  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  def init(config) do
    :erlang.process_flag(:trap_exit, true)
    Logger.info("runner init #{inspect(config)}")
    Load.Stats.init()

    :ets.new(@workers_tab, [:named_table, :public, :bag])

    config |> setup_nodes() |> setup_workers()

    Process.send_after(self(), :print_stats, :timer.seconds(10))

    # Make sleep time 10% shorter to compensate for timers latency but min 1ms
    sleep_ms = max(1, Keyword.get(config, :sleep_time_ms, @default_max_sleep_time_ms) * 9 / 10)

    state = %{
      sleep_ms: sleep_ms,
      config: config
    }
    print_usage()
    {:ok, state}
  end

  def add(ids \\ :all, count) when is_integer(count) and count > 0 and (ids == :all or is_list(ids)), do:
    GenServer.call(__MODULE__, {:add_workers, ids, count})

  def remove(ids \\ :all, count) when is_integer(count) and count > 0 and (ids == :all or is_list(ids)) do
    Enum.each(:ets.tab2list(:load_nodes), fn {node_id, _config} ->
    running_workers = :ets.lookup(:load_workers, node_id)
    if length(running_workers) > count do
      stop_workers(count, Enum.map(running_workers, &elem(&1, 1)))
    end
    end)
  end

  def on_worker_started(node_id, pid) do
    Logger.info("[#{__MODULE__}] worker #{node_id}/#{pid} started")
    :ets.insert(@workers_tab, {node_id, pid})
  end


  def on_worker_terminated(node_id, pid, reason) do
    Logger.error("[#{__MODULE__}] worker #{node_id}/#{pid} terminated for reason: #{reason}")
    ms = :ets.fun2ms(fn {_Node, p} -> p == pid end)
    :ets.select_delete(@workers_tab, ms)
  end


  def handle_info({EXIT, pid, reason}, state) do
    Process.unlink(pid)
    on_worker_terminated(:unknown, pid, reason)
    {:noreply, state}
  end

  defp setup_nodes(config) do
    :ets.new(@nodes_tab, [:named_table])

    Keyword.get(config, :load_nodes, [])
    |> Enum.each(fn node_config ->
      node_id = Keyword.get(node_config, :id)
      :ets.insert(@nodes_tab, {node_id, node_config})
      Logger.info("Customer node (as map): #{inspect(Enum.into(node_config, %{}))}")
    end)

    config
  end

  defp setup_workers(config) do
    Keyword.get(config, :load_nodes, [])
    |> Enum.each(fn _ -> create_workers_for_node(config) end)

    config
  end


  defp create_workers_for_node(config) do

    pids = Enum.map(1..Keyword.get(config, :workers_per_node), fn _ ->
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
