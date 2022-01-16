defmodule Load.Worker do
  use GenServer

  alias Load.Application

  require Logger

# state {
#     ref = erlang:ref_to_list(erlang:make_ref()),
#     inject_conn :: pid(), % Gun HTTP connection to inject entries.
#     node_id :: string(),
#     base_url,
#     headers :: list(),
#     sleep_time,
#     accum = {0, []} :: {integer(), any()},
#     stats_last_ms = 0, % when last stats were sent (milliseconds)
#     stats_reqs = 0,
#     stats_entries = 0,
#     stats_errors = 0,
# }

  def start_link(glob, args \\ []), do: GenServer.start_link(__MODULE__, glob ++ args |> Enum.into(%{}) )

  # def init(%{
  #   transport: transport,
  #   config: config,
  #   max_sleep: max_sleep
  # } = state) do
  #   host = Keyword.get(config, :host)
  #   host_ip =
  #     case :inet.getaddr(host, :inet) do

  #       {:ok, ip} -> ip
  #       {:error, reason} ->
  #         Logger.error("[#{__MODULE__}] init failed for host:#{inspect(host)} due to:#{inspect(reason)}")
  #         # TODO: check if this is just stopping the worker or something more
  #         # :init.stop()
  #         :timer.sleep(:timer.seconds(20))
  #     end
  #   Logger.debug("#{__MODULE__}:#{inspect(self())} targets ip:#{inspect(host_ip)} - host:#{inspect(host)}")
  #   port = Keyword.get(config, :port)

  #   http_opts =
  #     case transport do
  #       "http" -> %{}
  #       "https" -> %{transport: :ssl}
  #     end


  #   conn = create_connection(host_ip, port, http_opts)
  #   headers = [{"accept", "application/json"},
  #               {"content-type", "application/json"}]
  #   # Registering the worked in the :ets table
  #   Load.Stats.register_worker(self())
  #   :folsom_metrics.notify({:running_clients, {:inc, 1}})
  #   #Load.Runner.on_worker_started(__MODULE__, :node_id, self())

  #   Process.send(self(), :loop, [])

  #   state = %{
  #     node_id: :node_id,
  #     headers: headers,
  #     sleep_time: max_sleep,
  #     conn: conn,
  #     stats_last_ms: 0
  #   } |> Map.merge(state)
  #   {:ok, state}
  # end

  def init(args) do
    Logger.warn("init called with args: #{inspect(args)}")
    {:ok, %{}}
  end

  def handle_info(:loop, state), do: loop(state)


# terminate(_Reason, %{node_id: node_id}) ->
#     Load.Runner:on_worker_terminated(__MODULE__, node_id, self()).


# Myabe these could come from config
  @max_retries 5
  @gun_timeout :timer.seconds(30)
  @req_timeout :timer.seconds(30)

  defp create_connection(host_ip, port, http_opts), do:
    create_connection(host_ip, port, http_opts, @max_retries)


  defp create_connection(host_ip, port, _http_opts, 0) do
    Logger.error("Could not connect to host:#{inspect(host_ip)} port:#{inspect(port)} due to timeout")
    {:error, :timeout}
  end

  defp create_connection(host_ip, port, http_opts, max_retries) do
    {:ok, conn} = :gun.open(host_ip, port, http_opts)
    case :gun.await_up(conn, @gun_timeout) do
        {:ok, _} ->
            conn
        {:error, :timeout} ->
            :timer.sleep(:timer.seconds(2))
            create_connection(host_ip, port, http_opts, max_retries - 1)
        error ->
          Logger.error("Could not connect to host:#{inspect(host_ip)} port:#{inspect(port)} due to:#{inspect(error)}")
            error
    end
  end

  defp loop(%{
    base_url: base_url,
    ref: _ref_value,
    node_id: _node_id,
    conn: conn,
    headers: headers,
    stats_reqs: _stats_reqs} = state
    ) do

    # Leaving this out assuming it's message independent. If it's not, we'll
    # move in the behaviour implementation
    state = maybe_send_stats(state)

    # Provided we have a way to "understand" what message we received, we can trigger the
    # right module
    message_type = "audit_event_happened"
    module = Application.get_simulator_implementation(message_type)

    payload=module.process(state)
    state = update_state(state)

    # WE might want to hyde :gun behind a behaviour
    post_ref = :gun.post(conn, base_url <> "/entry", headers, payload)
    :folsom_metrics.notify({:sent_transactions, {:inc, 1}})
    g = :gun.await(conn, post_ref, @req_timeout)

    # TODO: let's find a home to this guy :P
    handle_result = fn {:response, _, code, _resp_headers}, post_ref, %{
      conn: conn,
      sleep_time: sleep_time,
      stats_entries: stats_entries} = state
      when div(code,2) == 0
      ->
      {:ok, _response_payload} = :gun.await_body(conn, post_ref, @req_timeout)

        # do something with response if necessary (e.g. schedule a verification)
        Process.send_after(self(), :loop, sleep_time)

        state = Map.put(state, :stats_entries, stats_entries + 1)
        {:noreply, state}
    end

    # Let's call the behaviour implementation, passing our function
    module.handle_result(handle_result, g, post_ref, state)

  end


  defp loop_handle_result(reason,_, %{sleep_time: sleep_time, stats_errors: stats_errors} = state) do
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

  defp update_state(%{stats_reqs: stats_reqs} = state), do:
    Map.put(state, :stats_reqs, stats_reqs + 1)
end
