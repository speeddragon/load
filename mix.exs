defmodule Load.MixProject do
  use Mix.Project

  def project do
    [
      app: :load,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Load.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:folsom, "~> 1.0"},
      {:gun, "~> 2.0.0-rc.2"},
      {:jason, "~> 1.3"},
      {:plug_cowboy, "~> 2.5"}

      # Code quality
      # {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      # {:credo, "~> 1.6", only: [:dev, :test], runtime: false}
    ]
  end
end
