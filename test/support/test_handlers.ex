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

  @impl Sassone.Handler
  def handle_event(event_type, event_data, acc) do
    {:ok, [{event_type, event_data} | acc]}
  end
end

defmodule SassoneTest.ControlHandler do
  @moduledoc false

  @behaviour Sassone.Handler

  @impl Sassone.Handler
  def handle_event(event, _data, {event, returning}), do: returning

  @impl Sassone.Handler
  def handle_event(event, data, {{event, data}, returning}), do: returning

  @impl Sassone.Handler
  def handle_event(_event, _data, state), do: {:ok, state}
end

defmodule SassoneTest.PrologHandler do
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

defmodule Struct do
  @moduledoc false

  @derive {Sassone.Builder, name: "test", attributes: [:foo], children: [:bar]}
  defstruct [:foo, :bar]
end

defmodule UnderivedStruct do
  @moduledoc false

  defstruct [:foo, :bar]
end

defmodule Post do
  @moduledoc false

  import Sassone.XML

  @derive {Sassone.Builder,
           name: "post",
           children: [
             :categories,
             categories: &__MODULE__.build_cats/1,
             categories: {__MODULE__, :build_categories}
           ]}
  defstruct [:categories]

  def build_categories(categories) do
    element(nil, "categories", [], categories)
  end

  def build_cats(categories) do
    element(nil, "cats", [], categories)
  end
end

defmodule Category do
  @moduledoc false

  @derive {Sassone.Builder, name: "category", attributes: [:name]}

  defstruct [:name]
end

defmodule Person do
  @moduledoc false

  import Sassone.XML

  @derive {
    Sassone.Builder,
    name: "person", attributes: [:gender], children: [:name, emails: &__MODULE__.build_emails/1]
  }
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
