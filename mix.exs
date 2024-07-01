defmodule ChannelSpec.MixProject do
  use Mix.Project

  @repo_url "https://github.com/felt/channel_spec"
  @version "0.1.8"

  def project do
    [
      app: :channel_spec,
      version: @version,
      elixir: "~> 1.13",
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:channel_handler, "~> 0.6"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:mneme, "~> 0.5", only: [:dev, :test]},
      {:json_xema, "~> 0.6"},
      {:phoenix, "~> 1.7"},
      {:xema, "~> 0.17.2"}
    ]
  end

  defp package do
    [
      description:
        "A Phoenix Channels specification library for automatic data validation and schema generation.",
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @repo_url
      }
    ]
  end

  defp docs do
    [
      extras: [
        LICENSE: [title: "License"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      homepage_url: @repo_url,
      source_ref: "v#{@version}",
      source_url: @repo_url,
      formatters: ["html"]
    ]
  end
end
