defmodule Load.Application do
  use Application

  @impl true
  @spec start(any, any) :: {:error, any} | {:ok, pid}
  def start(_type, _args) do
    Load.Stats.init()

    :hits |> :ets.new([:named_table, :public])
    :hits |> :ets.insert({:sent, 0})
    :hits |> :ets.insert({:errors, 0})
    :history |> :ets.new([:named_table, :public])
    :history |> :ets.insert({:rates, 0})

    children = [
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: Load.Router,
        options: [
          port: Application.get_env(:load, :ws_port, 8888),
          dispatch: dispatch()
        ]
      ),
      {DynamicSupervisor, strategy: :one_for_one, name: Load.Worker.Supervisor}, #, extra_arguments: [[a: :b]]}
      {DynamicSupervisor, strategy: :one_for_one, name: Load.Connection.Supervisor}
    ]
    opts = [strategy: :one_for_one, name: Load.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def dispatch do
    [
      {:_,
       [
         {"/ws", Load.WSHandler, []},
         {"/example/echo", Plug.Cowboy.Handler, {Example.EchoRouter, []}}
        #  {:_, Plug.Cowboy.Handler, {Example.EchoRouter, []}}
       ]}
    ]
  end

end
