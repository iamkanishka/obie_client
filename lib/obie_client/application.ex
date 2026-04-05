defmodule ObieClient.Application do
  @moduledoc false
  use Application

  @doc false
  @spec start(Application.start_type(), term()) :: {:ok, pid()} | {:error, term()}
  @impl true
  def start(_type, _args) do
    children = [
      ObieClient.Cache,
      ObieClient.CircuitBreaker.Registry,
      ObieClient.RateLimiter.Supervisor
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: ObieClient.Supervisor)
  end
end
