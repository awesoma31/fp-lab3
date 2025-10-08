defmodule Lab3.MixProject do
  use Mix.Project

  def project do
    [
      app: :lab3,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      escript: escript(),
      deps: deps()
    ]
  end

  defp escript do
    [
      main_module: InterpolationApp.CLI,
      path: "./out/interpolation_app",
      name: "interpolation_app"
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
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
