defmodule Example.EchoRouter do
  use Plug.Router

  require Logger



  plug :match
  plug Plug.Parsers, parsers: [:json], json_decoder: Jason
  plug :dispatch

  post "/example/echo" do
    params = Map.get(conn, :body_params)
    send_resp(conn, 200, params)
  end

  get "/example/echo" do
    send_resp(conn, 200, "ok")
  end

end
