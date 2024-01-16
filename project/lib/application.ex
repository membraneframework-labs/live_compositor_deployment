defmodule CompositorExample.Application do
  use Application

  alias Membrane.RTMP.Source.TcpServer

  @impl true
  def start(_type, _args) do
    File.mkdir_p("output")

    # Start HTTP server that serves output directory.
    {:ok, _server} =
      :inets.start(:httpd,
        bind_address: ~c"0.0.0.0",
        port: 9001,
        document_root: ~c"./output",
        server_name: ~c"compositor_example",
        server_root: "."
      )

    Membrane.Pipeline.start_link(Membrane.Demo.CompositorExample, [])
  end
end
