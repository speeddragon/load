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
    Logger.debug("received ping")
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
      %{"command" => "scale", "count" => count} ->
        count = Supervisor.which_children(Load.Worker.Supervisor)
        |> Enum.reduce(count, fn {:undefined, pid, :worker, [Load.Worker]}, acc ->
          acc = acc - 1
          if acc < 0 do
            DynamicSupervisor.terminate_child(Load.Worker.Supervisor, pid)
          end
          acc
        end)
        1..count
        |> Enum.each(fn _ ->
          DynamicSupervisor.start_child(Load.Worker.Supervisor, {Load.Worker,
            host: "localhost",
            port: "8888",
            opts: %{transport: :tcp, protocols: [:http]},
            sim: Example.EchoSim,
            run_interval: :timer.seconds(1)
          })
        end)
        {:reply, {:text, Jason.encode!(%{ok: :ok})}, state}
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
