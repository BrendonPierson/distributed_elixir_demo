defmodule DD.Mixfile do
  use Mix.Project

  def project do
    [
      app: :dist_demo,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {DD.Application, []}
    ]
  end

  defp deps do
    [
      {:swarm, "~> 3.0"},
      {:sweet_xml, "~> 0.3"},
      {:ex_aws, "1.1.2"},
    ]
  end
end
