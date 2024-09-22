defmodule Sassone.Builder.Description do
  @moduledoc """
  A struct representing the description of an XML element or attribute.
  """

  @type type :: :element | :attribute

  @type field_name :: atom()

  @type t :: %__MODULE__{
          field_name: field_name(),
          deserialize: boolean(),
          many: boolean(),
          struct: module(),
          serialize: boolean(),
          type: type(),
          recased_name: String.t()
        }

  @enforce_keys [:field_name, :deserialize, :serialize, :type, :recased_name]
  defstruct field_name: nil,
            deserialize: true,
            many: false,
            struct: nil,
            serialize: true,
            type: nil,
            recased_name: nil

  schema = [
    case: [
      doc: "Recase the struct field names automatically with the given strategy.",
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
              doc: "If false, the struct field won't be parsed from XML.",
              type: :boolean,
              default: true
            ],
            serialize: [
              doc: "If false, the field will be ignored when building the struct to XML.",
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
              doc: "Custom field name for parsing and building. It will be used as-is.",
              type: :string
            ],
            struct: [
              doc: "A struct deriving `Sibill.Builder` used to parse and build this element.",
              type: :atom
            ],
            type: [
              doc: "How the field is represented in XML: `:element`, `:attribute`, `:content`.",
              type: {:in, [:element, :attribute]},
              default: :element
            ]
          ]
        ]
      ],
      required: true
    ],
    namespace: [
      doc: "XML namespace of the element.",
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
