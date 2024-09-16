defmodule Sassone.TestHandlers.StackHandler do
  @moduledoc false

  @behaviour Sassone.Handler

  def handle_event(event_type, event_data, acc) do
    {:ok, [{event_type, event_data} | acc]}
  end
end

defmodule SassoneTest.StackHandler do
  @moduledoc false

  @behaviour Sassone.Handler

  @impl true
  def handle_event(event_type, event_data, acc) do
    {:ok, [{event_type, event_data} | acc]}
  end
end

defmodule SassoneTest.ControlHandler do
  @moduledoc false

  @behaviour Sassone.Handler

  @impl true
  def handle_event(event_type, _, {event_type, returning}) do
    returning
  end

  def handle_event(event_type, event_data, {{event_type, event_data}, returning}) do
    returning
  end

  def handle_event(_, _, state) do
    {:ok, state}
  end
end

# For docs test

defmodule MyTestHandler do
  @moduledoc false

  @behaviour Sassone.Handler

  def handle_event(:start_document, prolog, state) do
    {:ok, [{:start_document, prolog} | state]}
  end

  def handle_event(:end_document, _data, state) do
    {:ok, [{:end_document} | state]}
  end

  def handle_event(:start_element, {namespace, name, attributes}, state) do
    {:ok, [{:start_element, namespace, name, attributes} | state]}
  end

  def handle_event(:end_element, name, state) do
    {:ok, [{:end_element, name} | state]}
  end

  def handle_event(:characters, chars, state) do
    {:ok, [{:chacters, chars} | state]}
  end
end

defmodule Person do
  @moduledoc false

  @derive {
    Sassone.Builder,
    name: "person", attributes: [:gender], children: [:name, emails: &__MODULE__.build_emails/1]
  }

  import Sassone.XML

  defstruct [:name, :gender, emails: []]

  def build_emails(emails) do
    email_count = Enum.count(emails)

    element(
      nil,
      "emails",
      [count: email_count],
      Enum.map(emails, &element(nil, "email", [], &1))
    )
  end
end

defmodule User do
  @moduledoc false

  defstruct [:username, :name]
end

defimpl Sassone.Builder, for: User do
  import Sassone.XML

  def build(user) do
    element(
      nil,
      "Person",
      [{"userName", user.username}],
      [element(nil, "Name", [], user.name)]
    )
  end
end
