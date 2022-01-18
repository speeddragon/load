defmodule Example.AuditSimulator do
  @moduledoc """
  This will live in an implementation package (in the client domain)
  """

  @behaviour Load.Simulator

  alias Load.Simulator

  require Logger

  @impl Simulator
  def process(%{
      ref: ref_value,
      node_id: node_id} = state) do

    Logger.info("Received message: #{inspect(state)}")

    id = (
        DateTime.utc_now |> DateTime.to_unix(:millisecond)
      ) * :timer.seconds(1000) + :rand.uniform(:timer.seconds(1000))

    text = [node(), node_id, ref_value, id] |> Enum.map(&inspect/1) |> Enum.join("_")
    %{ encoding: "base64", value: Base.encode64(text)} |> Jason.encode!()
  end

  @impl Simulator
  def handle_result(f, g, post_ref, state), do:    f.(g, post_ref, state)
end
