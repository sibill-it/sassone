defmodule Bench.NoopHandler do
  @behaviour Sassone.Handler

  @impl Sassone.Handler
  def handle_event(_, _, state), do: {:ok, state}

  @doc "Handler for Erlsom"
  def handle_event(_, state), do: state
end
