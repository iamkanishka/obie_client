defmodule ObieClient.MixProject do
  use Mix.Project

  @version "1.0.0"
  @source_url "https://github.com/iamkanishka/obie_client"

  def project do
    [
      app: :obie_client,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description:
        "Production-grade Elixir client for the UK Open Banking (OBIE) Read/Write API v3.1.3",
      package: package(),
      name: "ObieClient",
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test
      ],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix],
        flags: [:error_handling, :underspecs]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto, :ssl, :public_key],
      mod: {ObieClient.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},
      {:joken, "~> 2.6"},
      {:plug, "~> 1.15"},
      {:jose, "~> 1.11"},
      {:uniq, "~> 0.6"},
      {:telemetry, "~> 1.2"},
      {:telemetry_metrics, "~> 0.6"},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:bypass, "~> 2.1", only: :test},
      {:mox, "~> 1.1", only: :test},
      {:stream_data, "~> 0.6", only: [:dev, :test]}
    ]
  end

  defp aliases do
    [
      "test.all": ["test --include integration"],
      lint: ["format --check-formatted", "credo --strict", "dialyzer"],
      check: ["compile --warnings-as-errors", "credo --strict", "test"]
    ]
  end

  defp package do
    [
      maintainers: ["Kanishka Naik"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "OBIE Spec" => "https://openbankinguk.github.io/read-write-api-site2/"
      },
      files: ~w(lib config mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "ObieClient",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md"],
      groups_for_modules: [
        Core: [ObieClient, ObieClient.Client, ObieClient.Config, ObieClient.Error],
        AIS: [ObieClient.AISP.Consent, ObieClient.Accounts],
        PIS: [ObieClient.Payments, ObieClient.FilePayments],
        CBPII: [ObieClient.Funds],
        VRP: [ObieClient.VRP],
        Events: [ObieClient.EventNotifications, ObieClient.Events.Handler],
        Auth: [ObieClient.Auth.TokenManager, ObieClient.Auth.JWT, ObieClient.Auth.MTLS],
        Signing: [ObieClient.Signing.JWS],
        Resilience: [ObieClient.CircuitBreaker, ObieClient.RateLimiter, ObieClient.Cache],
        Types: [ObieClient.Types.Enums, ObieClient.Types.Common],
        Utilities: [ObieClient.Validation, ObieClient.Telemetry, ObieClient.Pagination]
      ]
    ]
  end
end
