defmodule ChannelSpec.MixProject do
  use Mix.Project

  def project do
    [
      app: :channel_spec,
      version: "0.1.1",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:channel_handler, "~> 0.1"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:mneme, "~> 0.5", only: [:dev, :test]},
      {:json_xema, "~> 0.6"},
      {:phoenix, "~> 1.7"},
      {:xema, "~> 0.17"}
    ]
  end
end
