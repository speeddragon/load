defmodule Load.Stats do

  @stats_table :load_stats
  @empty_stats  %{
    req_count: 0,
    entry_count: 0,
    error_count: 0,
    request_rate: 0,
    entry_rate: 0,
    error_rate: 0,
    last_update_ms: 0
    }
  def init do
    :ets.new(@stats_table, [:named_table, :public])
  end

  def register_worker(pid) do
    # Write down start time and zeroes
    # TODO: Trap linked worker exits and delete from stats
    :ets.insert(@stats_table, {pid, @empty_stats})
  end


  # @doc NOTE: To be called from worker, not from controller (runner)
  def update_stats(pid, %{
    req_count: req_count,
    entry_count: entry_count,
    error_count: error_count,
    duration_since_last_update: duration_ms
    }) do
      %{
        req_count: total_requests,
        entry_count: total_entries,
        error_count: total_errors
      } =
        case :ets.lookup(@stats_table, pid) do
          [{_k, stats}] -> stats
          [] -> @empty_stats
        end
      request_rate = calculate_rate(duration_ms, req_count)
      ingestion_rate = calculate_rate(duration_ms, entry_count)
      error_rate = calculate_rate(duration_ms, error_count)
      id = :ets.update_counter(:history, :rates, 1)
      :ets.insert(:history, {id, %{request_rate: request_rate, ingestion_rate: ingestion_rate, error_rate: error_rate}})
      :ets.insert(@stats_table, {pid, %{
        req_count: total_requests + req_count,
        entry_count: total_entries + entry_count,
        error_count: total_errors + error_count,
        request_rate: request_rate,
        entry_rate: ingestion_rate,
        error_rate: error_rate,
        last_update_ms: DateTime.utc_now |> DateTime.to_unix(:millisecond)
      }})
  end

  @amin :timer.minutes(1)

  def get_stats do
  # Delete records older than 30 seconds
  #    TooOld = :ets.fun2ms(
  #        fun({_, #worker_stats{last_update_ms = LU}}) when LU < (DateTime.utc_now |> DateTime.to_unix(:millisecond) - :timer.seconds(30)) ->
  #            true
  #        end),
  #    :ets.select_delete(@stats_table, TooOld),


    #Collect sum of other stats
    now_ms = DateTime.utc_now |> DateTime.to_unix(:millisecond)
    sum_stats = Enum.reduce(:ets.tab2list(@stats_table), Map.put(@empty_stats, :last_update_ms, -1),
        fn ({_k, %{last_update_ms: lu} = ws}, acc) when now_ms - lu < @amin ->
              Map.merge(ws,acc, fn _k, v1, v2 ->
                v1 + v2
              end)
           (_, acc) -> acc
        end)

    total_requests = Map.get(sum_stats, :req_count)
    error_count = Map.get(sum_stats, :error_count)
    error_pct = case total_requests do
                   0 -> 0.0;
                   _ -> error_count * 100.0 / total_requests
               end

    Map.put(sum_stats, :error_pct, error_pct)

  end

  defp calculate_rate(duration_ms, count) do
    if duration_ms > 0 do
      count * :timer.seconds(1) / duration_ms
    else
      0.0
    end
  end

end
