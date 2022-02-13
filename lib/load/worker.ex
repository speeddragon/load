defmodule Load.Worker do

  use GenServer, restart: :transient

  require Logger

  @connect_delay 200
  # @retry_interval :timer.seconds(20)
  @req_timeout :timer.seconds(5)

  def start_link(glob, args \\ []), do: GenServer.start_link(__MODULE__, glob ++ args |> Enum.into(%{}) )

  def init(args) do

    Logger.debug("init called with args: #{inspect(args)}")

    host = Map.get(args, :host)
    port = Map.get(args, :port)
    opts = Map.get(args, :opts)
    sim = Map.get(args, :sim)
    run_interval = Map.get(args, :run_interval)

    Process.send_after(self(), :connect, @connect_delay)

    state = %{
      host: String.to_charlist(host),
      port: String.to_integer(port),
      opts: opts,
      sim: sim,
      run_interval: run_interval,
      stats_last_ms: 0, # when last stats were sent (milliseconds)
      stats_reqs: 0,
      stats_entries: 0,
      stats_errors: 0,
    }

    {:ok, state}
  end

  def handle_info(:connect, %{host: host, port: port, opts: opts} = state) do

    # TODO handle as case
    {:ok, conn} = :gun.open(host, port, opts)
    {:ok, _transport} = :gun.await_up(conn)

    Process.send_after(self(), :run, 0)

    {:noreply, Map.put(state, :conn, conn)}

  end


  def handle_info(:run, %{sim: sim, run_interval: run_interval} = state) do
    state = state
    |> maybe_send_stats()
    |> sim.run()
    Process.send_after(self(), :run, run_interval)
    {:noreply, state}
  end

  def hit(target, headers, payload, %{host: host, port: port, conn: conn, stats_entries: stats_entries, opts: %{protocols: protocols, transport: transport}} = state) do


    case {protocols, transport} do
      {[:http], :tcp} ->
        [verb, path] = String.split(target, " ")
        case verb do
          "POST" ->
            Logger.debug("hitting http://#{host}:#{port}#{path}")
            post_ref = :gun.post(conn, "http://#{host}:#{port}#{path}", headers, payload)
            :folsom_metrics.notify({:sent_transactions, {:inc, 1}})
            g = :gun.await(conn, post_ref, @req_timeout)
            {:ok, resp_payload} = handle_result(g, post_ref, state)
            state = Map.put(state, :stats_entries, stats_entries + 1)
            {:ok, resp_payload, state}
          _ ->
            {:error , "http tcp #{verb} not_implemented"}
        end

      _ ->
        {:error , "not_implemented"}

    end
  end


  defp handle_result({:response, _, code, _resp_headers}, post_ref, %{conn: conn}) do
    if div(code, 100) == 2 do
      {:ok, resp_payload} = :gun.await_body(conn, post_ref, @req_timeout)
      {:ok, resp_payload}
    else
      {:error, "reponse code #{code}"}
    end

  end

  defp handle_result(reason,_, %{sleep_time: sleep_time, stats_errors: stats_errors} = state) do
    :folsom_metrics.notify({:http_errors, {:inc, 1}})

    Logger.error("Error (#{inspect(self())}) #{inspect(reason)}")

    Process.send_after(self(), :loop, sleep_time)

    state = Map.put(state, :stats_errors, stats_errors + 1)
    {:noreply, state}

  end

  # TODO: move this in config ?
  @periodic_stats_min_duration :timer.seconds(1)

  defp maybe_send_stats(%{
    stats_last_ms: last,
    stats_entries: entries,
    stats_errors: errors,
    stats_reqs: reqs} = state) do

    now = DateTime.utc_now |> DateTime.to_unix(:millisecond)
    duration = now - last
    if duration > @periodic_stats_min_duration do
      Load.Stats.update_stats(self(), %{
        req_count: reqs,
        entry_count: entries,
        error_count: errors,
        duration_since_last_update: duration
      })

      Map.merge(state, %{
        stats_last_ms: now,
        stats_entries: 0,
        stats_errors: 0,
        stats_reqs: 0
      })
    else
      state
    end

  end


end


    # case :gun.await_up(conn, @gun_timeout) do
    #     {:ok, _} ->
    #         conn
    #     {:error, :timeout} ->
    #         :timer.sleep(:timer.seconds(2))
    #         create_connection(host_ip, port, http_opts, max_retries - 1)
    #     error ->
    #       Logger.error("Could not connect to host:#{inspect(host_ip)} port:#{inspect(port)} due to:#{inspect(error)}")
    #         error
    # end


  # def handle_info(:get_ip, %{host: host} = state) do

  #   case :inet.getaddr(host, :inet) do

  #     {:ok, ip} ->
  #       Process.send_after(self(), :connect, 0)
  #       {:noreply, Map.put(state, :ip, ip)}

  #     {:error, reason} ->
  #       Logger.error("[#{__MODULE__}] init failed for host:#{inspect(host)} due to:#{inspect(reason)}")
  #       Process.send_after(self(), :get_ip, @connect_delay)
  #   end

  # end
