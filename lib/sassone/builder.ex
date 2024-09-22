defprotocol Sassone.Builder do
  alias Sassone.Builder.Description

  @moduledoc """
  Protocol to implement XML serialization and deserialization for a struct.

  You can derive or implement this protocol for your structs, and then use `Sassone.XML.serialize/2`
  and `Sassone.XML.deserialize/2` to convert the struct to and from XML.

  When deriving the protocol, these are the supported options:

  #{Description.__schema__() |> NimbleOptions.new!() |> NimbleOptions.docs()}
  """

  @typedoc "A strut implementing `Sassone.Builder`"
  @type t :: struct()

  @doc """
  Returns the list of attributes that are serialized/deserialized for this XML resource.
  """
  @spec attributes(t()) :: [Description.t()]
  def attributes(resource)

  @doc """
  Builds a resource for encoding with `Sassone.encode!/2`
  """
  def build(resource)

  @doc """
  Returns the list of elements that are serialized/deserialized for this XML resource.
  """
  @spec elements(t()) :: [Description.t()]
  def elements(resource)

  @doc """
  Returns the namespace for the XML resource.
  """
  @spec namespace(t()) :: String.t() | nil
  def namespace(resource)

  @doc """
  Returns the parser module the XML resource.
  """
  @spec parser(t()) :: module()
  def parser(_resource)

  @doc """
  Returns the root for the XML resource.
  """
  @spec root_element(t()) :: String.t()
  def root_element(resource)
end

defimpl Sassone.Builder, for: Any do
  alias Sassone.Builder
  alias Sassone.Builder.Description

  import Sassone.XML

  @moduledoc """
  Default implementation of the `Sassone.Builder` protocol for any struct.

  Options:
  #{NimbleOptions.docs(Description.__schema__())}
  """

  defmacro __deriving__(module, struct, options) do
    options =
      options
      |> normalize_default_options()
      |> Macro.prewalk(&Macro.expand(&1, __CALLER__))
      |> NimbleOptions.validate!(NimbleOptions.new!(Description.__schema__()))

    struct_members = struct |> Map.keys() |> MapSet.new()
    field_names = options[:fields] |> Keyword.keys() |> MapSet.new()

    if not MapSet.subset?(field_names, struct_members) do
      difference = MapSet.difference(field_names, struct_members)

      raise "Mismatching fields in the declaration. Missing fields: #{inspect(MapSet.to_list(difference))}"
    end

    fields = Enum.map(options[:fields], &to_description(&1, options[:case]))

    {elements, attributes} =
      Enum.split_with(fields, fn %Description{} = description ->
        description.type == :element
      end)

    start_document = generate_start_document()
    end_document = generate_end_document(module)
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

        def attributes(_resource), do: unquote(Macro.escape(attributes))

        def build(resource), do: XML.build_resource(resource, Builder.root_element(resource))

        def elements(_resource), do: unquote(Macro.escape(elements))
        def namespace(_resource), do: unquote(options[:namespace])
        def root_element(_resource), do: unquote(options[:root_element])
        def parser(_resource), do: __MODULE__
      end
    end
  end

  def attributes(_resource), do: []
  def build(_resournce), do: nil
  def elements(_resource), do: []
  def namespace(_resource), do: nil
  def parser(_resource), do: nil
  def root_element(_resource), do: "Root"

  defp normalize_default_options(options) do
    {_, options} =
      get_and_update_in(options, [:fields, Access.all()], fn
        field when is_tuple(field) -> {field, field}
        field -> {field, {field, []}}
      end)

    options
  end

  defp to_description({field_name, options}, case) do
    %Description{
      struct(Description, options)
      | recased_name: options[:name] || recase(field_name, case) |> to_string(),
        field_name: field_name
    }
  end

  defp recase(field_name, :pascal), do: Recase.to_pascal(field_name)
  defp recase(field_name, :camel), do: Recase.to_camel(field_name)
  defp recase(field_name, :snake), do: Recase.to_snake(field_name)
  defp recase(field_name, :kebab), do: Recase.to_kebab(field_name)

  defp generate_start_document do
    quote do
      @impl Sassone.Handler
      def handle_event(:start_document, _data, _state),
        do: {:ok, %Parser{parsers: [__MODULE__]}}
    end
  end

  defp generate_end_document(module) do
    quote do
      @impl Sassone.Handler
      def handle_event(:end_document, _data, %Parser{} = parser) do
        Code.ensure_loaded!(unquote(module))

        if function_exported?(unquote(module), :changeset, 2) do
          case unquote(module).changeset(struct(unquote(module)), parser.state)
               |> Ecto.Changeset.apply_action(:cast) do
            {:ok, schema} -> {:ok, schema}
            {:error, _changeset} = error -> {:stop, error}
          end
        else
          {:ok, parser.state}
        end
      end
    end
  end

  defp generate_start_element(elements) do
    Enum.filter(elements, & &1.deserialize)
    |> Enum.reduce(
      [
        quote do
          @impl Sassone.Handler
          def handle_event(:start_element, _data, state), do: {:ok, state}
        end
      ],
      fn
        %Description{resource: nil} = description, functions ->
          [
            quote do
              @impl Sassone.Handler
              def handle_event(
                    :start_element,
                    {_ns, unquote(description.recased_name) = element, _attributes} = data,
                    %Parser{} = parser
                  ) do
                elements = [unquote(description.recased_name) | parser.elements]
                keys = [unquote(description.field_name) | parser.keys]
                parser = %Parser{parser | elements: elements, keys: keys}

                {:ok, parser}
              end
            end
            | functions
          ]

        %Description{many: false} = description, functions ->
          [
            quote do
              @impl Sassone.Handler
              def handle_event(
                    :start_element,
                    {_ns, unquote(description.recased_name) = element, _attributes} = data,
                    %Parser{} = parser
                  ) do
                elements = [unquote(description.recased_name) | parser.elements]
                keys = [unquote(description.field_name) | parser.keys]
                next_parser = unquote(Builder.parser(struct(description.resource)))
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

        %Description{many: true} = description, functions ->
          [
            quote do
              @impl Sassone.Handler
              def handle_event(
                    :start_element,
                    {_ns, unquote(description.recased_name) = element, _attributes} = data,
                    %Parser{} = parser
                  ) do
                elements = [unquote(description.recased_name) | parser.elements]
                keys = [unquote(description.field_name) | parser.keys]
                next_parser = unquote(Builder.parser(struct(description.resource)))
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

        _description, functions ->
          functions
      end
    )
  end

  defp generate_characters(elements) do
    Enum.filter(elements, & &1.deserialize)
    |> Enum.reduce(
      [
        quote do
          @impl Sassone.Handler
          def handle_event(:characters, _data, state), do: {:ok, state}
        end
      ],
      fn
        %Description{resource: nil, many: false} = description, functions ->
          [
            quote do
              @impl Sassone.Handler
              def handle_event(
                    :characters,
                    data,
                    %Parser{
                      elements: [unquote(description.recased_name) | _],
                      keys: [unquote(description.field_name) | _]
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

        %Description{resource: nil, many: true} = description, functions ->
          [
            quote do
              @impl Sassone.Handler
              def handle_event(
                    :characters,
                    data,
                    %Parser{
                      elements: [unquote(description.recased_name) | _],
                      keys: [unquote(description.field_name) | _]
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

        _description, functions ->
          functions
      end
    )
  end

  defp generate_end_element(elements) do
    Enum.filter(elements, & &1.deserialize)
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
        %Description{resource: nil} = description, functions ->
          [
            quote do
              @impl Sassone.Handler
              def handle_event(
                    :end_element,
                    {_ns, unquote(description.recased_name) = element},
                    %Parser{keys: [_key | keys], elements: [element | elements]} = parser
                  ) do
                parser = %Parser{parser | keys: keys, elements: elements}

                {:ok, parser}
              end
            end
            | functions
          ]

        %Description{many: false} = description, functions ->
          [
            quote do
              @impl Sassone.Handler
              def handle_event(
                    :end_element,
                    {_ns, unquote(description.recased_name) = element},
                    %Parser{keys: [_key | keys], elements: [element | elements]} = parser
                  ) do
                parser = %Parser{parser | keys: keys, elements: elements}

                {:ok, parser}
              end
            end
            | functions
          ]

        _description, functions ->
          functions
      end
    )
  end
end
