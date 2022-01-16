defmodule Load.WebsocketHandler do
  @moduledoc """
  Module to handle the socket connections
  """

  @behaviour :cowboy_websocket
  # terminate if no activity for one minute

  require Logger

  @impl true
  def init(req, _state) do
    state = %{caller: req.pid}
    {:cowboy_websocket, req, state}
  end

  @impl true
  # Handle 'ping' messages from the browser - reply
  def websocket_handle(:ping, state) do
    IO.puts("received ping")
    {:reply, :pong, state}
  end

  @impl true
  def websocket_handle({:text, message}, state) do
    IO.puts("received #{message}")
    {:reply, {:text, "ok"}, state}
  end

  @impl true
  def websocket_info(_message, state) do
    {:ok, state}
  end

  @impl true
  def terminate(_reason, _req, _state) do
    Logger.info("terminated")
    :ok
  end

end
