defmodule Noizu.Confluence.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/noizu-labs-sdks/noizu_confluence"

  def project do
    [
      app: :noizu_confluence,
      version: @version,
      description:
        "Elixir client for the Confluence Cloud REST API (v2 primary, v1 only where v2 has no equivalent).",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      source_url: @source_url,
      homepage_url: @source_url
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:req, "~> 0.7"},
      {:jason, "~> 1.4"},
      {:plug, "~> 1.16", only: :test},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md", "docs/API-CONTRACT.md", "LICENSE"]
    ]
  end

  defp package do
    [
      name: "noizu_confluence",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib docs/API-CONTRACT.md CHANGELOG.md LICENSE README.md mix.exs)
    ]
  end
end
