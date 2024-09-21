defmodule Sassone.XML do
  alias Sassone.Builder

  @moduledoc """
  Helper functions for building XML elements.
  """

  @type character_type :: :entity | :hexadecimal | :decimal

  @type characters :: {:characters, String.t()}

  @type cdata :: {:cdata, String.t()}

  @type comment :: {:comment, String.t()}

  @type ref :: entity_ref() | hex_ref() | dec_ref()

  @type entity_ref :: {:reference, {:entity, String.t()}}

  @type hex_ref :: {:reference, {:hexadecimal, integer()}}

  @type dec_ref :: {:reference, {:decimal, integer()}}

  @type processing_instruction ::
          {:processing_instruction, name :: String.t(), instruction :: String.t()}

  @type namespace :: String.t() | nil

  @type attribute :: {name :: String.t(), value :: String.t()}

  @type element_name :: String.t()

  @type element :: {
          namespace :: String.t() | nil,
          name :: String.t(),
          attributes :: [attribute()],
          children :: [content()]
        }

  @type content :: element() | characters() | cdata() | ref() | comment() | String.t()

  @compile {
    :inline,
    [
      element: 4,
      characters: 1,
      cdata: 1,
      comment: 1,
      reference: 2,
      processing_instruction: 2
    ]
  }

  @doc "Builds empty element in simple form."
  @spec empty_element(namespace(), element_name(), [attribute()]) :: element()
  def empty_element(namespace, name, attributes) do
    {
      namespace && to_string(namespace),
      to_string(name),
      Enum.map(attributes, &attribute/1),
      []
    }
  end

  @doc "Builds element in simple form."
  @spec element(namespace(), element_name(), [attribute()], term()) :: element()
  def element(namespace, name, attributes, children) do
    {
      namespace && to_string(namespace),
      to_string(name),
      Enum.map(attributes, &attribute/1),
      children(List.wrap(children))
    }
  end

  @doc "Builds characters in simple form."
  @spec characters(text :: term()) :: characters()
  def characters(text), do: {:characters, to_string(text)}

  @doc "Builds CDATA in simple form."
  @spec cdata(text :: term()) :: cdata()
  def cdata(text), do: {:cdata, to_string(text)}

  @doc "Builds comment in simple form."
  @spec comment(text :: term()) :: comment()
  def comment(text), do: {:comment, to_string(text)}

  @doc "Builds reference in simple form."
  @spec reference(character_type(), value :: term()) :: ref()
  def reference(:entity, name) when not is_nil(name), do: {:reference, {:entity, to_string(name)}}

  def reference(character_type, integer)
      when character_type in [:hexadecimal, :decimal] and is_integer(integer),
      do: {:reference, {character_type, integer}}

  @doc "Builds processing instruction in simple form."
  @spec processing_instruction(String.t(), String.t()) :: processing_instruction()
  def processing_instruction(name, instruction) when not is_nil(name),
    do: {:processing_instruction, to_string(name), instruction}

  defp children(children, acc \\ [])

  defp children([binary | children], acc) when is_binary(binary),
    do: children(children, [binary | acc])

  defp children([{type, _value} = form | children], acc)
       when type in [:characters, :comment, :cdata, :reference],
       do: children(children, [form | acc])

  defp children([{_namespace, _name, _attributes, _content} = form | children], acc),
    do: children(children, [form | acc])

  defp children([child | children], acc) do
    children(
      children,
      child |> Builder.build() |> List.wrap() |> Enum.reverse() |> Kernel.++(acc)
    )
  end

  defp children([], acc), do: Enum.reverse(acc)

  defp attribute({name, value}), do: {to_string(name), to_string(value)}
end
