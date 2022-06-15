import Config

config :load, :worker_specs,
  host: "elixir-ilp",
  port: "7770",
  opts: %{transport: :http, protocols: [:ilp_packet]},
  sim: Example.PacketSim,
  run_interval: :timer.seconds(1)
