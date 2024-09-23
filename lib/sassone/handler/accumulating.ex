defmodule Sassone.Handler.Accumulating do
  @moduledoc false

  @behaviour Sassone.Handler

  @impl Sassone.Handler
  def handle_event(event, data, state), do: {:ok, [{event, data} | state]}
end
