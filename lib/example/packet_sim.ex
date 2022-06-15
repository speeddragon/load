defmodule Example.PacketSim do
  @behaviour Load.Sim

  require Logger

  @prepare_execution_condition """
  \x11\x7b\x43\x4f\x1a\x54\xe9\x04\x4f\x4f\x54\x92\x3b\x2c\xff\x9e\
  \x4a\x6d\x42\x0a\xe2\x81\xd5\x02\x5d\x7b\xb0\x40\xc4\xb4\xc0\x4a\
  """

  @impl true
  def run(state) do
    data = %{
      "amount" => 107,
      "data" => "",
      "destination" => "example.alice",
      "execution_condition" => @prepare_execution_condition,
      "expires_at" => "2023-06-07T20:48:42.483Z"
    }

    {:ok, payload} = IlpPacket.encode_prepare(data)

    path = Application.get_env(:load, :ilp_path, "/send_money/ilp")

    {:ok, res_payload, new_state} =
      Load.Worker.hit(
        path,
        [{"content-type", "application/octet-stream"}],
        payload,
        state
      )

    decoded_response = IlpPacket.decode(res_payload)
    Logger.debug("sim received back #{inspect(decoded_response)}")

    new_state
  end
end
