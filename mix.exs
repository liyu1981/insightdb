defmodule Insightdb.Mixfile do
  use Mix.Project

  def project do
    [app: :insightdb,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env:
       ["coveralls": :test, "coveralls.detail": :test, "coveralls.post": :test, "coveralls.html": :test],
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:mongodb, git: "git://github.com/ericmj/mongodb.git"},
     {:poolboy, "~>1.5.0"},
     {:db_connection, "~> 1.1"},
     {:poison, "~> 3.0"},
     {:httpoison, "~> 0.10.0"},
     {:secure_random, "~> 0.5"},
     {:excoveralls, "~> 0.6", only: :test},
     {:mock, "~> 0.2.0", only: :test},
     {:stash, "~> 1.0.0", only: :test}]
  end
end
