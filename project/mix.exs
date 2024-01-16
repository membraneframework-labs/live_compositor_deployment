defmodule CompositorExample.MixProject do
  use Mix.Project

  def project do
    [
      app: :compositor_example,
      version: "0.1.0",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {CompositorExample.Application, []},
      extra_applications: [:inets]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:membrane_core, "~> 1.0"},
      {:membrane_rtmp_plugin, github: "membraneframework/membrane_rtmp_plugin"},
      {:membrane_http_adaptive_stream_plugin, "~> 0.18.4"},
      {:membrane_live_compositor_plugin,
       github: "membraneframework/membrane_live_compositor_plugin"},
      {:dialyxir, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
