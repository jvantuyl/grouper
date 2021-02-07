defmodule Grouper.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :grouper,
      version: "0.1.0",
      elixir: "~> 1.11.1",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Grouper",
      description: "Isolates groups of process subtrees together for configuration and name registration purposes.",
      source_url: "https://github.com/jvantuyl/grouper",
      package: package(),
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore.exs"
      ],
      docs: docs()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Grouper.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex2ms, "~> 1.0"},
      # doc
      {:ex_doc, "~> 0.23", only: :dev, runtime: false},
      # testing / quality
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false}
    ]
  end


  defp package() do
    [licenses: ["MIT"], links: %{"GitHub" => "https://github.com/jvantuyl/grouper"}]
  end

  defp docs() do
    [
      main: "readme",
      api_reference: false,
      extras: ["README.md": [title: "Overview"], "LICENSE.md": [title: "License"]],
      authors: ["Jayson Vantuyl"],
      source_ref: "v#{@version}"
    ]
  end
end
