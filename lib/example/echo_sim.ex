defmodule Example.EchoSim do

  @behaviour Load.Sim

  require Logger

  @impl true
  def run(state) do

    payload = "a content"
    {:ok, res_payload, state} = Load.Worker.hit("POST /example/echo", [], payload, state)
    Logger.info("sim received back #{res_payload}")
    state

  end


end
