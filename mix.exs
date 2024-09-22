defmodule Sassone.MixProject do
  use Mix.Project

  @source_url "https://github.com/sibill-it/sassone"
  @version "1.0.0"

  def project() do
    [
      app: :sassone,
      version: @version,
      elixir: "~> 1.12",
      name: "Sassone",
      consolidate_protocols: Mix.env() != :test,
      deps: deps(),
      package: package(),
      docs: docs()
    ]
  end

  def application(), do: []

  defp package() do
    [
      description:
        "Sassone is an XML parser and encoder in Elixir that focuses on speed " <>
          "and standard compliance.",
      maintainers: ["Cẩm Huỳnh"],
      licenses: ["MIT"],
      links: %{
        "Changelog" => "https://hexdocs.pm/sassone/changelog.html",
        "GitHub" => @source_url
      }
    ]
  end

  defp deps() do
    [
      {:credo, "~> 1.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: :dev, runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:stream_data, "~> 1.0", only: [:dev, :test]},
      {:nimble_options, "~> 1.0"},
      {:recase, "~> 0.8"}
    ]
  end

  defp docs() do
    [
      extras: [
        "CHANGELOG.md",
        {:"LICENSE.md", [title: "License"]},
        "README.md",
        "guides/getting-started-with-sax.md"
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      assets: %{"assets" => "assets"},
      formatters: ["html"],
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end
end
