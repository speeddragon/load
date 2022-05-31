defmodule Example.PacketSim do
  @behaviour Load.Sim

  require Logger

  @impl true
  def run(state) do
    data = %{
      "amount" => 107,
      "data" => "",
      "destination" => "example.alice",
      "execution_condition" => "",
      "expires_at" => "2023-06-07T20:48:42.483Z"
    }

    payload = IlpPacket.encode_prepare(data)
    {:ok, res_payload, new_state} = Load.Worker.hit("/send_money/ilp", [], payload, state)
    Logger.debug("sim received back #{res_payload}")
    new_state
  end
end
