defmodule Load.WSClient do

  use GenServer, restart: :transient

  require Logger

  def start_link(glob, args \\ []), do: GenServer.start_link(__MODULE__, glob ++ args |> Enum.into(%{}))

  @impl true
  def init(args) do
    Process.send_after(self(), :connect, :timer.seconds(1))
    state = args
    {:ok, state}
  end

  @impl true
  def handle_info(:connect, state) do
    {:ok, conn} = :gun.open(state.address |> to_charlist(), _port = 8888, %{retry: 0})
    {:ok, _transport} = :gun.await_up(conn)
    _stream = :gun.ws_upgrade(conn, "/ws" |> to_charlist())
    {:noreply, Map.put(state, :conn, conn)}
  end

  @impl true
  def handle_info({:gun_ws, _conn, _, {:text, message}}, state) do
    case Jason.decode!(message) do
      _ ->
        Logger.error("[#{__MODULE__}] invalid")
    end
    {:noreply, state}
  end

  @impl true
  def handle_info({:gun_down, conn, _ws, _closed, _, _}, state) do
    Logger.warn("[#{__MODULE__}] Socket down #{state.address}")
    :ok = :gun.close(conn)
    :ok = :gun.flush(conn)
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:gun_ws, conn, _ws, :close}, state) do
    Logger.warn("[#{__MODULE__}] Socket closed #{state.address}")
    :ok = :gun.close(conn)
    :ok = :gun.flush(conn)
    {:stop, :normal, state}
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
  def handle_call(:get_address, _from, state) do
    {:reply, state.address, state}
  end

  @impl true
  def handle_cast({:ws_send, address, message}, state) do
    if address == :all or address == state.address do
      :ok = :gun.ws_send(state.conn, {:text, Jason.encode!(message)})
    end
    {:noreply, state}
  end

end
