defmodule Load.Applicaiton do
  use Application

  @impl true
  def start(_type, _args) do
    start_folsom_metrics()
    children = []
    opts = [strategy: :one_for_one, name: Ted.Supervisor]
    Supervisor.start_link(children, opts)
  end


  defp start_folsom_metrics do

    :folsom_metrics.new_gauge(:request_rate)
    :folsom_metrics.new_gauge(:ingestion_rate)
    :folsom_metrics.new_gauge(:error_rate)
    :folsom_metrics.new_counter(:sent_transactions)
    :folsom_metrics.new_counter(:verified_transactions)
    :folsom_metrics.new_counter(:http_errors)
    :folsom_metrics.new_counter(:unconfirmed_transactions)
    :folsom_metrics.new_counter(:running_clients)
  end
end
