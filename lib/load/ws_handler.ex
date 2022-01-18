defmodule Load.WSHandler do
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
    case Jason.decode!(message) do
      %{"command" => "terminate"} ->
        Supervisor.which_children(Load.Worker.Supervisor)
        |> Enum.each(fn {:undefined, pid, :worker, [Load.Worker]} ->
          DynamicSupervisor.terminate_child(Load.Worker.Supervisor, pid)
        end)
        {:stop, state}
      _ ->
        {:reply, {:text, "invalid"}, state}
        # IO.puts("received #{message}")
    end

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
