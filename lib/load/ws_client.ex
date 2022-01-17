defmodule Load.WSClient do

  use GenServer

  require Logger

  def start_link(glob, args \\ []), do: GenServer.start_link(__MODULE__, glob ++ args |> Enum.into(%{}) , name: Tmp)

  @impl true
  def init(args) do
    Process.send_after(self(), :connect, :timer.seconds(1))
    state = args
    {:ok, state}
  end

  @impl true
  def handle_info(:connect, state) do
    {:ok, conn} = :gun.open(state.address, _port = 8888, %{retry: 0})
    {:ok, _transport} = :gun.await_up(conn)
    _stream = :gun.ws_upgrade(conn, "/ws" |> to_charlist())
    {:noreply, Map.put(state, :conn, conn)}
  end

  @impl true
  def handle_info({:gun_ws, _conn, _, {:text, _msg}}, state) do
    Logger.info("[#{__MODULE__}] Message received")
    {:noreply, state}
  end

  @impl true
  def handle_info({:gun_down, _conn, _ws, _closed, _, _}, state) do
    Logger.warn("[#{__MODULE__}] Socket down")
    {:noreply, state}
  end

  @impl true
  def handle_info({:gun_ws, _conn, _ws, :close}, state) do
    Logger.warn("[#{__MODULE__}] Socket closed")
    {:noreply, state}
  end

  @impl true
  def handle_info({:gun_upgrade, _conn, _mon, _type, _info}, state) do
    Logger.warn("[#{__MODULE__}] Connection upgraded")
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warn("[#{__MODULE__}] unknown info received #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def handle_cast(_request, state) do
    :gun.ws_send(state.conn, {:text, "hello"})
    {:noreply, state}
  end

  # DynamicSupervisor.start_child(Load.Connection.Supervisor, {Load.WSClient, address: '127.0.0.1'})
  # GenServer.cast(Tmp, :something)
end
