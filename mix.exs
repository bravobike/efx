defmodule Efx.MixProject do
  use Mix.Project

  @version "0.2.2"
  @github_page "https://github.com/bravobike/efx"

  def project do
    [
      app: :efx,
      version: @version,
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # doc
      name: "Efx",
      description: "A library to declaratively write testable effects for asynchronous testing",
      homepage_url: @github_page,
      source_url: @github_page,
      docs: docs(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Efx.Application, []}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:typed_struct, "~> 0.3.0"},
      {:process_tree, "0.1.2"}
    ]
  end

  defp docs() do
    [
      api_reference: false,
      authors: ["Simon Härer"],
      canonical: "http://hexdocs.pm/efx",
      main: "Efx",
      source_ref: "v#{@version}"
    ]
  end

  defp package do
    [
      files: ~w(mix.exs README.md lib),
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @github_page
      },
      maintainers: ["Simon Härer"]
    ]
  end
end
