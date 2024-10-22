defmodule Sassone.XML do
  @moduledoc """
  Helper functions for building XML elements.
  """

  @type character_type :: :entity | :hexadecimal | :decimal

  @type characters :: {:characters, String.t()}

  @type cdata :: {:cdata, String.t()}

  @type comment :: {:comment, String.t()}

  @type entity_ref :: {:reference, {:entity, String.t()}}

  @type hex_ref :: {:reference, {:hexadecimal, integer()}}

  @type dec_ref :: {:reference, {:decimal, integer()}}

  @type ref :: entity_ref() | hex_ref() | dec_ref()

  @type content :: element() | characters() | cdata() | ref() | comment() | String.t()

  @type namespace :: String.t() | nil

  @type name :: String.t()

  @type value :: term()

  @type attribute :: {namespace(), name(), value()}

  @type element :: {namespace(), name(), [attribute()], [content()]}

  @type processing_instruction :: {:processing_instruction, name(), instruction :: String.t()}

  @compile {
    :inline,
    [
      attribute: 2,
      attribute: 3,
      cdata: 1,
      characters: 1,
      comment: 1,
      element: 3,
      element: 4,
      empty_element: 2,
      empty_element: 3,
      processing_instruction: 2,
      reference: 2
    ]
  }

  alias Sassone.{Builder, Encoder}
  alias Sassone.Builder.Field

  @doc "Builds attribute in simple form."
  @spec attribute(namespace(), name(), value()) :: attribute()
  def attribute(namespace \\ nil, name, value), do: {namespace, name, Encoder.encode(value)}

  @doc "Builds empty element in simple form."
  @spec empty_element(namespace(), name(), [attribute()]) :: element()
  def empty_element(namespace \\ nil, name, attributes),
    do: {namespace, name, attributes, []}

  @doc "Builds element in simple form."
  @spec element(namespace(), name(), [attribute()], [content()]) :: element()
  def element(namespace \\ nil, name, attributes, children),
    do: {namespace, name, attributes, children}

  @doc "Builds characters in simple form."
  @spec characters(text :: term()) :: characters()
  def characters(text) when is_list(text), do: {:characters, to_string(text)}
  def characters(text), do: {:characters, Encoder.encode(text)}

  @doc "Builds CDATA in simple form."
  @spec cdata(text :: term()) :: cdata()
  def cdata(text) when is_list(text), do: {:cdata, to_string(text)}
  def cdata(text), do: {:cdata, Encoder.encode(text)}

  @doc "Builds comment in simple form."
  @spec comment(text :: term()) :: comment()
  def comment(text) when is_list(text), do: {:comment, to_string(text)}
  def comment(text), do: {:comment, Encoder.encode(text)}

  @doc "Builds reference in simple form."
  @spec reference(character_type(), value :: term()) :: ref()
  def reference(:entity, name), do: {:reference, {:entity, Encoder.encode(name)}}

  def reference(character_type, integer) when character_type in [:hexadecimal, :decimal],
    do: {:reference, {character_type, integer}}

  @doc "Builds processing instruction in simple form."
  @spec processing_instruction(String.t(), String.t()) :: processing_instruction()
  def processing_instruction(name, instruction),
    do: {:processing_instruction, name, Encoder.encode(instruction)}

  @doc "Builds a struct for encoding with `Sassone.encode!/2`"
  @spec build(Builder.t(), name()) :: element()
  def build(struct, element_name) do
    attributes =
      Builder.attributes(struct)
      |> Enum.reduce([], &build_attributes(struct, &1, &2))
      |> Enum.reverse()

    elements =
      Builder.elements(struct)
      |> Enum.reduce([], &build_elements(struct, &1, &2))
      |> Enum.reverse()

    element(Builder.namespace(struct), element_name, attributes, elements)
  end

  defp build_attributes(_struct, %Field{build: false}, attributes),
    do: attributes

  defp build_attributes(struct, %Field{} = field, attributes),
    do: build_attribute(field, Map.get(struct, field.name), attributes)

  defp build_attribute(_field, nil, attributes), do: attributes

  defp build_attribute(field, value, attributes),
    do: [attribute(field.xml_name, value) | attributes]

  defp build_elements(_struct, %Field{build: false}, elements),
    do: elements

  defp build_elements(struct, %Field{} = field, elements),
    do: build_element(field, Map.get(struct, field.name), elements)

  defp build_element(_field, value, elements) when value in [nil, []],
    do: elements

  defp build_element(%Field{} = field, values, elements)
       when is_list(values) do
    Enum.reduce(values, elements, &build_element(field, &1, &2))
  end

  defp build_element(%Field{} = field, value, elements) do
    if Builder.impl_for(value) do
      [build(value, field.xml_name) | elements]
    else
      [element(field.xml_name, [], [characters(value)]) | elements]
    end
  end
end
