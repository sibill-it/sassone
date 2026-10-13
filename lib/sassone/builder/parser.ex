defmodule Sassone.Builder.Parser do
  @moduledoc false

  alias Sassone.Builder
  alias Sassone.Builder.Field

  defstruct depth: 0, elements: [], handlers: [], keys: [], state: %{}, struct: nil

  @doc "Helper function to parse and element attributes"
  def parse_attributes(struct, attributes) do
    Builder.attributes(struct)
    |> Enum.filter(fn %Field{} = field -> field.parse end)
    |> Enum.reduce(%{}, fn %Field{} = field, state ->
      Enum.find_value(attributes, state, fn
        {namespace, attribute, value}
        when namespace == field.namespace and attribute == field.xml_name ->
          Map.put(state, field.name, value)

        {_ns, _attribute, _value} ->
          nil
      end)
    end)
  end
end
