defmodule Example.AuditSim do
  @moduledoc """
  This will live in an implementation package (in the client domain)
  """

  @behaviour Load.Sim

  require Logger

  @impl true
  def run(state) do

    payload = ""
    {:ok, _res_payload, state} = Load.Worker.hit("POST /qualcosa", [], payload, state)
    state

  end


end
