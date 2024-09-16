defmodule Sassone.SimpleForm.Handler do
  @moduledoc false

  @behaviour Sassone.Handler

  @impl Sassone.Handler
  def handle_event(:start_document, _prolog, stack) do
    {:ok, stack}
  end

  @impl Sassone.Handler
  def handle_event(:start_element, {ns, tag_name, attributes}, stack) do
    tag = {ns, tag_name, attributes, []}
    {:ok, [tag | stack]}
  end

  @impl Sassone.Handler
  def handle_event(:characters, chars, stack) do
    [{ns, tag_name, attributes, content} | stack] = stack

    current = {ns, tag_name, attributes, [chars | content]}

    {:ok, [current | stack]}
  end

  @impl Sassone.Handler
  def handle_event(:cdata, chars, stack) do
    [{ns, tag_name, attributes, content} | stack] = stack

    current = {ns, tag_name, attributes, [{:cdata, chars} | content]}

    {:ok, [current | stack]}
  end

  @impl Sassone.Handler
  def handle_event(:end_element, {ns, tag_name}, [{ns, tag_name, attributes, content} | stack]) do
    current = {ns, tag_name, attributes, Enum.reverse(content)}

    case stack do
      [] ->
        {:ok, current}

      [parent | rest] ->
        {parent_ns, parent_tag_name, parent_attributes, parent_content} = parent
        parent = {parent_ns, parent_tag_name, parent_attributes, [current | parent_content]}
        {:ok, [parent | rest]}
    end
  end

  @impl Sassone.Handler
  def handle_event(:end_document, _, stack) do
    {:ok, stack}
  end
end
