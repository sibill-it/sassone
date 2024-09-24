defprotocol Sassone.Builder do
  @moduledoc """
  Protocol to implement XML serialization and deserialization for a struct.

  You can derive or implement this protocol for your structs

  When deriving the protocol, these are the supported options:

  #{Sassone.Builder.Field.__schema__() |> NimbleOptions.new!() |> NimbleOptions.docs()}
  """

  alias Sassone.XML
  alias Sassone.Builder.Field

  @typedoc "A strut implementing `Sassone.Builder`"
  @type t :: struct()

  @doc """
  Returns the mapping of attributes for the struct.
  """
  @spec attributes(t()) :: [Field.t()]
  def attributes(struct)

  @doc """
  Builds the struct for encoding with `Sassone.encode!/2`
  """
  @spec build(t) :: XML.element() | nil
  def build(struct)

  @doc """
  Returns the mapping of elements for the struct.
  """
  @spec elements(t()) :: [Field.t()]
  def elements(t)

  @doc """
  Returns the XML namespace for the struct.
  """
  @spec namespace(t()) :: String.t() | nil
  def namespace(t)

  @doc """
  Returns the `Sassone.Handler` implementation for the struct.
  """
  @spec handler(t()) :: module()
  def handler(t)

  @doc """
  Returns the XML root element name for the struct.
  """
  @spec root_element(t()) :: String.t()
  def root_element(t)
end

defimpl Sassone.Builder, for: Any do
  alias Sassone.Builder
  alias Sassone.Builder.Field

  @moduledoc """
  Default implementation of the `Sassone.Builder` protocol for any struct.

  Options:
  #{NimbleOptions.docs(Field.__schema__())}
  """

  defmacro __deriving__(module, struct, options) do
    options =
      options
      |> normalize_default_options()
      |> Macro.prewalk(&Macro.expand(&1, __CALLER__))
      |> NimbleOptions.validate!(NimbleOptions.new!(Field.__schema__()))

    struct_members = struct |> Map.keys() |> MapSet.new()
    names = options[:fields] |> Keyword.keys() |> MapSet.new()

    if not MapSet.subset?(names, struct_members) do
      difference = MapSet.difference(names, struct_members)

      raise "Mismatching fields in the declaration. Missing fields: #{inspect(MapSet.to_list(difference))}"
    end

    fields =
      Enum.map(options[:fields], fn {name, field_options} ->
        case =
          if options[:type] == :attribute do
            options[:attribute_case]
          else
            options[:element_case]
          end

        xml_name = field_options[:name] || recase(to_string(name), case)
        %Field{struct(Field, field_options) | xml_name: xml_name, name: name}
      end)

    {attributes, elements} =
      Enum.split_with(fields, fn %Field{} = field -> field.type == :attribute end)

    start_document = generate_start_document(module)
    end_document = generate_end_document()
    start_element = generate_start_element(elements)
    characters = generate_characters(elements)
    end_element = generate_end_element(elements)

    if options[:debug] do
      end_document |> Macro.to_string() |> IO.puts()
      start_element |> Macro.to_string() |> IO.puts()
      characters |> Macro.to_string() |> IO.puts()
      end_element |> Macro.to_string() |> IO.puts()
    end

    quote do
      defimpl Sassone.Builder, for: unquote(module) do
        @behaviour Sassone.Handler

        alias Sassone.XML
        alias Sassone.Builder.Parser

        unquote(start_document)
        unquote(end_document)
        unquote(start_element)
        unquote(characters)
        unquote(end_element)

        def attributes(_t), do: unquote(Macro.escape(attributes))
        def build(t), do: XML.build(t, Builder.root_element(t))
        def elements(_t), do: unquote(Macro.escape(elements))
        def handler(_t), do: __MODULE__
        def namespace(_t), do: unquote(options[:namespace])
        def root_element(_t), do: unquote(options[:root_element])
      end
    end
  end

  def attributes(_t), do: []
  def build(_t), do: nil
  def elements(_t), do: []
  def handler(_t), do: nil
  def namespace(_t), do: nil
  def root_element(_t), do: "Root"

  defp normalize_default_options(options) do
    {_, options} =
      get_and_update_in(options, [:fields, Access.all()], fn
        field when is_tuple(field) -> {field, field}
        field -> {field, {field, []}}
      end)

    options
  end

  defp recase(name, :pascal), do: Recase.to_pascal(name)
  defp recase(name, :camel), do: Recase.to_camel(name)
  defp recase(name, :snake), do: Recase.to_snake(name)
  defp recase(name, :kebab), do: Recase.to_kebab(name)

  defp generate_start_document(module) do
    quote do
      @impl Sassone.Handler
      def handle_event(:start_document, _data, _state),
        do: {:ok, %Parser{struct: unquote(module), parsers: [__MODULE__]}}
    end
  end

  defp generate_end_document do
    quote do
      @impl Sassone.Handler
      def handle_event(:end_document, _data, %Parser{} = parser) do
        {:ok, {parser.struct, parser.state}}
      end
    end
  end

  defp generate_start_element(elements) do
    Enum.filter(elements, fn %Field{} = field -> field.parse end)
    |> Enum.reduce(
      [
        quote do
          @impl Sassone.Handler
          def handle_event(:start_element, _data, state), do: {:ok, state}
        end
      ],
      fn
        %Field{struct: nil} = field, functions ->
          [
            quote do
              @impl Sassone.Handler
              def handle_event(
                    :start_element,
                    {_ns, unquote(field.xml_name) = element, _attributes} = data,
                    %Parser{} = parser
                  ) do
                elements = [unquote(field.xml_name) | parser.elements]
                keys = [unquote(field.name) | parser.keys]
                parser = %Parser{parser | elements: elements, keys: keys}

                {:ok, parser}
              end
            end
            | functions
          ]

        %Field{many: false} = field, functions ->
          [
            quote do
              @impl Sassone.Handler
              def handle_event(
                    :start_element,
                    {_ns, unquote(field.xml_name) = element, _attributes} = data,
                    %Parser{} = parser
                  ) do
                elements = [unquote(field.xml_name) | parser.elements]
                keys = [unquote(field.name) | parser.keys]
                next_parser = unquote(Builder.handler(struct(field.struct)))
                parsers = [next_parser | parser.parsers]
                state = put_in(parser.state, Enum.reverse(keys), %{})

                parser = %Parser{
                  parser
                  | elements: elements,
                    keys: keys,
                    parsers: parsers,
                    state: state
                }

                {:cont, next_parser, parser}
              end
            end
            | functions
          ]

        %Field{many: true} = field, functions ->
          [
            quote do
              @impl Sassone.Handler
              def handle_event(
                    :start_element,
                    {_ns, unquote(field.xml_name) = element, _attributes} = data,
                    %Parser{} = parser
                  ) do
                elements = [unquote(field.xml_name) | parser.elements]
                keys = [unquote(field.name) | parser.keys]
                next_parser = unquote(Builder.handler(struct(field.struct)))
                parsers = [next_parser | parser.parsers]

                state =
                  update_in(parser.state, Enum.reverse(keys), fn
                    nil -> [%{}]
                    values -> values ++ [%{}]
                  end)

                parser = %Parser{
                  parser
                  | elements: [:__LAST__ | elements],
                    keys: [Access.at(-1) | keys],
                    parsers: parsers,
                    state: state
                }

                {:cont, next_parser, parser}
              end
            end
            | functions
          ]

        _field, functions ->
          functions
      end
    )
  end

  defp generate_characters(elements) do
    Enum.filter(elements, fn %Field{} = field -> field.parse end)
    |> Enum.reduce(
      [
        quote do
          @impl Sassone.Handler
          def handle_event(:characters, _data, state), do: {:ok, state}
        end
      ],
      fn
        %Field{struct: nil, many: false} = field, functions ->
          [
            quote do
              @impl Sassone.Handler
              def handle_event(
                    :characters,
                    data,
                    %Parser{
                      elements: [unquote(field.xml_name) | _],
                      keys: [unquote(field.name) | _]
                    } = parser
                  ) do
                state =
                  update_in(parser.state, Enum.reverse(parser.keys), fn
                    nil -> String.trim(data)
                    values -> values <> String.trim(data)
                  end)

                parser = %Parser{parser | state: state}

                {:ok, parser}
              end
            end
            | functions
          ]

        %Field{struct: nil, many: true} = field, functions ->
          [
            quote do
              @impl Sassone.Handler
              def handle_event(
                    :characters,
                    data,
                    %Parser{
                      elements: [unquote(field.xml_name) | _],
                      keys: [unquote(field.name) | _]
                    } = parser
                  ) do
                state =
                  update_in(parser.state, Enum.reverse(parser.keys), fn
                    nil -> [String.trim(data)]
                    values -> values ++ [String.trim(data)]
                  end)

                parser = %Parser{parser | state: state}

                {:ok, parser}
              end
            end
            | functions
          ]

        _field, functions ->
          functions
      end
    )
  end

  defp generate_end_element(elements) do
    Enum.filter(elements, fn %Field{} = field -> field.parse end)
    |> Enum.reduce(
      [
        quote do
          @impl Sassone.Handler
          def handle_event(
                :end_element,
                {_ns, element},
                %Parser{
                  keys: [_index, _key | keys],
                  elements: [:__LAST__, element | elements],
                  parsers: [_cur_paser, prev_parser | parsers]
                } = parser
              ) do
            parser = %Parser{
              parser
              | keys: keys,
                elements: elements,
                parsers: [prev_parser | parsers]
            }

            {:cont, prev_parser, parser}
          end
        end,
        quote do
          @impl Sassone.Handler
          def handle_event(
                :end_element,
                {_ns, element},
                %Parser{
                  keys: [_key | keys],
                  elements: [element | elements],
                  parsers: [_cur_paser, prev_parser | parsers]
                } = parser
              ) do
            parser = %Parser{
              parser
              | keys: keys,
                elements: elements,
                parsers: [prev_parser | parsers]
            }

            {:cont, prev_parser, parser}
          end
        end,
        quote do
          @impl Sassone.Handler
          def handle_event(
                :end_element,
                {_ns, element},
                %Parser{
                  keys: [_key | keys],
                  elements: [element | elements],
                  parsers: [_cur_paser, prev_parser | parsers]
                } = parser
              ) do
            parser = %Parser{
              parser
              | keys: keys,
                elements: elements,
                parsers: [prev_parser | parsers]
            }

            {:cont, prev_parser, parser}
          end
        end,
        quote do
          @impl Sassone.Handler
          def handle_event(:end_element, _data, state), do: {:ok, state}
        end
      ],
      fn
        %Field{struct: nil} = field, functions ->
          [
            quote do
              @impl Sassone.Handler
              def handle_event(
                    :end_element,
                    {_ns, unquote(field.xml_name) = element},
                    %Parser{keys: [_key | keys], elements: [element | elements]} = parser
                  ) do
                parser = %Parser{parser | keys: keys, elements: elements}

                {:ok, parser}
              end
            end
            | functions
          ]

        %Field{many: false} = field, functions ->
          [
            quote do
              @impl Sassone.Handler
              def handle_event(
                    :end_element,
                    {_ns, unquote(field.xml_name) = element},
                    %Parser{keys: [_key | keys], elements: [element | elements]} = parser
                  ) do
                parser = %Parser{parser | keys: keys, elements: elements}

                {:ok, parser}
              end
            end
            | functions
          ]

        _field, functions ->
          functions
      end
    )
  end
end
