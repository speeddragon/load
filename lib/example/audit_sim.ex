defmodule Example.AuditSim do

  @behaviour Load.Sim

  require Logger

  @impl true
  def run(state) do

    payload = "a content"
    {:ok, _res_payload, state} = Load.Worker.hit("POST /some_path", [], payload, state)
    # consume res_payload and maybe change the state
    payload = "another content"
    {:ok, _res_payload, state} = Load.Worker.hit("POST /some_other_path", [], payload, state)
    # consume res_payload and maybe change the state
    state

  end


end
