import Config

config :load, :worker_specs,
  host: "localhost",
  port: "7770",
  opts: %{transport: :http, protocols: [:ilp_packet]},
  sim: Example.PacketSim,
  run_interval: :timer.seconds(1)
