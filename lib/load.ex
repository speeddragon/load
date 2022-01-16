defmodule Load do

  require Logger

  def scale(count, node_id \\ :all) when is_integer(count) and count > 0 and (node_id == :all or is_binary(node_id)) do
    case node_id do
      :all ->
        GenServer.call(Load.Runner, :get)
        |> Enum.each(fn server ->
          {:ok, conn} = :gun.open(server, _port = 8888, %{retry: 0})
          {:ok, _val} = :gun.await_up(conn)

          # stream = :gun.ws_upgrade(conn, "/ws" |> to_charlist() , [
          #     {"Authorization", "Bearer test"}
          #   ])

          # Logger.warn("stream #{stream}")
          # :gun.ws_send(conn, {:text, "scale #{count}"})
        end)

        # :ets.tab2list(:active_nodes)
       _ ->
        # :ets.lookup(:active_nodes, node_id)
        :ok
    end
    # :gun.open(server, port, tls)
  end

  def set(nodes) when is_list(nodes), do:
    :ok = GenServer.call(Load.Runner, {:set, nodes |> Enum.map(&to_charlist/1)})

    # GenServer.call(Load.Runner, {:scale, node_id, count})
  def i, do: Load.Stats.get_stats()

end
