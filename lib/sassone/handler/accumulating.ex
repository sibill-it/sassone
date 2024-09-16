defmodule Sassone.Handler.Accumulating do
  # Accumulating handler originally intended to be
  # used with stream transformations
  @moduledoc false

  @behaviour Sassone.Handler

  def handle_event(event, data, state) do
    {:ok, [{event, data} | state]}
  end
end
