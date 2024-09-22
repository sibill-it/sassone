defmodule Sassone.Builder.Description do
  @moduledoc """
  A struct representing the description of an XML resource element or attribute.
  """

  @type type :: :element | :attribute

  @type field_name :: atom()

  @type t :: %__MODULE__{
          field_name: field_name(),
          deserialize: boolean(),
          many: boolean(),
          resource: module(),
          serialize: boolean(),
          type: type(),
          recased_name: String.t()
        }

  @enforce_keys [:field_name, :deserialize, :serialize, :type, :recased_name]
  defstruct field_name: nil,
            deserialize: true,
            many: false,
            resource: nil,
            serialize: true,
            type: nil,
            recased_name: nil

  schema = [
    case: [
      doc: "Recase the resource field names automatically with the given strategy.",
      type: {:in, [:pascal, :camel, :snake, :kebab]},
      default: :pascal
    ],
    debug: [doc: "Enable debug for parser generation.", type: :boolean, default: false],
    fields: [
      doc:
        "Resource fields to map to XML. The order of elements will be preserved in the generated XML.",
      type: :keyword_list,
      keys: [
        *: [
          type: :keyword_list,
          keys: [
            deserialize: [
              doc: "If false, the resource field won't be deserialized from XML.",
              type: :boolean,
              default: true
            ],
            serialize: [
              doc: "If false, the resource field won't be serialized to XML.",
              type: :boolean,
              default: true
            ],
            many: [
              doc:
                "Specifies if the element can be repeated and should be serialized and deserialized as a list.",
              type: :boolean,
              default: false
            ],
            name: [
              doc:
                "Custom resource field name for serialization and deserialization. If defined, it will be used as-is instead of recasing.",
              type: :string
            ],
            resource: [
              doc:
                "If the element is represented by another resource, it needs to be specified here.",
              type: :atom
            ],
            type: [
              doc: "The XML shape that the resource field has in XML.",
              type: {:in, [:element, :attribute]},
              default: :element
            ]
          ]
        ]
      ],
      required: true
    ],
    namespace: [
      doc: "XML namespace to apply to the resource when serializing.",
      type: {:or, [:string, nil]},
      default: nil
    ],
    root_element: [
      doc: "XML root element. This applies only to the toplevel Resource when (de)serializing.",
      type: :string,
      default: "Root"
    ]
  ]

  def __schema__, do: unquote(schema)
end
