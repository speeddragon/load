defmodule Load.Worker do

  use GenServer, restart: :transient

  require Logger

  @connect_delay 200
  @req_timeout :timer.seconds(5)

  def start_link(glob, args \\ []), do: GenServer.start_link(__MODULE__, glob ++ args |> Enum.into(%{}) )

  def init(args) do

    Logger.debug("init called with args: #{inspect(args)}")

    state = args
    |> Map.take([:opts, :sim])
    |> Map.put(:host, String.to_charlist(args.host))
    |> Map.put(:port, String.to_integer(args.port))
    |> Map.put(:interval_ms, apply(:timer,
      Application.get_env(:load, :worker_timeunit, :seconds), [
      Application.get_env(:load, :worker_interval, 5)
    ]))
    |> Map.put(:stats_interval_ms, apply(:timer,
      Application.get_env(:load, :worker_stats_timeunit, :seconds), [
      Application.get_env(:load, :worker_stats_interval, 1)
    ]))
    |> Map.merge(Stats.empty())

    Process.send_after(self(), :connect, @connect_delay)

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
    |> sim.run()
    |> Stats.maybe_update()
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
            :ets.update_counter(:hits, :sent, 1)
            g = :gun.await(conn, post_ref, @req_timeout)
            {:ok, resp_payload} = handle_result(g, post_ref, state)
            state = Map.put(state, :stats_entries, stats_entries + 1)
            {:ok, resp_payload, state}
          _ ->
            {:error , "http tcp #{verb} not_implemented"}
        end

      {[:ilp_packet], :http} ->
        Logger.debug("hitting http://#{host}:#{port}#{target}")

        post_ref = :gun.post(conn, "http://#{host}:#{port}#{target}", headers, payload)
        :ets.update_counter(:hits, :sent, 1)
        g = :gun.await(conn, post_ref, @req_timeout)
        {:ok, resp_payload} = handle_result(g, post_ref, state)
        state = Map.put(state, :stats_entries, stats_entries + 1)
        {:ok, resp_payload, state}

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
    :ets.update_counter(:hits, :errors, 1)

    Logger.error("Error (#{inspect(self())}) #{inspect(reason)}")

    Process.send_after(self(), :loop, sleep_time)

    state = Map.put(state, :stats_errors, stats_errors + 1)
    {:noreply, state}

  end

end

    # this is for websocket?
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
