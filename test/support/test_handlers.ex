defmodule Sassone.TestHandlers do
  @moduledoc false

  defmodule StackHandler do
    @moduledoc false

    @behaviour Sassone.Handler

    @impl Sassone.Handler
    def handle_event(event_type, event_data, acc) do
      {:ok, [{event_type, event_data} | acc]}
    end
  end

  defmodule ControlHandler do
    @moduledoc false

    @behaviour Sassone.Handler

    @impl Sassone.Handler
    def handle_event(event, _data, {event, returning}), do: returning

    @impl Sassone.Handler
    def handle_event(event, data, {{event, data}, returning}), do: returning

    @impl Sassone.Handler
    def handle_event(_event, _data, state), do: {:ok, state}
  end

  defmodule PrologHandler do
    @moduledoc false

    @behaviour Sassone.Handler

    @impl Sassone.Handler
    def handle_event(:start_document, prolog, _state), do: {:stop, prolog}
  end

  defmodule MyTestHandler do
    @moduledoc false

    @behaviour Sassone.Handler

    @impl Sassone.Handler
    def handle_event(:start_document, data, state), do: {:ok, [{:start_document, data} | state]}

    @impl Sassone.Handler
    def handle_event(:end_document, _data, state), do: {:ok, [{:end_document} | state]}

    @impl Sassone.Handler
    def handle_event(:start_element, {namespace, name, attributes}, state),
      do: {:ok, [{:start_element, namespace, name, attributes} | state]}

    @impl Sassone.Handler
    def handle_event(:end_element, name, state), do: {:ok, [{:end_element, name} | state]}

    @impl Sassone.Handler
    def handle_event(:characters, chars, state), do: {:ok, [{:chacters, chars} | state]}
  end
end
