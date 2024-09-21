defmodule SassoneTest do
  use SassoneTest.ParsingCase, async: true

  alias SassoneTest.{ControlHandler, StackHandler}

  doctest Sassone

  @fixtures [
    "no-xml-decl.xml",
    "no-xml-decl-with-std-pi.xml",
    "no-xml-decl-with-custom-pi.xml",
    "foo.xml",
    "food.xml",
    "complex.xml",
    "illustrator.svg",
    "unicode.xml"
  ]

  test "parses XML document binary and streams" do
    for fixture_name <- @fixtures do
      data = read_fixture(fixture_name)
      assert {:ok, _state} = parse(data, StackHandler, [])
    end
  end

  test "parses file streams" do
    for fixture_name <- @fixtures do
      stream = stream_fixture(fixture_name)
      assert {:ok, _state} = Sassone.parse_stream(stream, StackHandler, [])
    end
  end

  test "maps file streams" do
    for fixture <- @fixtures do
      stream = stream_fixture(fixture)
      element_stream = Sassone.stream_events(stream)
      assert [_ | _] = Enum.to_list(element_stream)
    end

    assert_raise Sassone.ParseError, fn ->
      Enum.to_list(Sassone.stream_events(stream_fixture("incorrect.xml")))
    end
  end

  test "parse_string/4 parses XML binary with multiple \":expand_entity\" strategy" do
    data = "<foo>Something &unknown;</foo>"

    assert {:ok, state} = parse(data, StackHandler, [], expand_entity: :keep)

    assert state == [
             {:end_document, {}},
             {:end_element, {nil, "foo"}},
             {:characters, "Something &unknown;"},
             {:start_element, {nil, "foo", []}},
             {:start_document, []}
           ]

    assert {:ok, state} = parse(data, StackHandler, [], expand_entity: :skip)

    assert state == [
             {:end_document, {}},
             {:end_element, {nil, "foo"}},
             {:characters, "Something "},
             {:start_element, {nil, "foo", []}},
             {:start_document, []}
           ]

    assert {:ok, state} =
             parse(data, StackHandler, [], expand_entity: {__MODULE__, :convert_entity, []})

    assert state == [
             {:end_document, {}},
             {:end_element, {nil, "foo"}},
             {:characters, "Something known"},
             {:start_element, {nil, "foo", []}},
             {:start_document, []}
           ]
  end

  test "parse_string/4 parses XML binary with closing tags containing whitespaces" do
    data = "<foo>Some data</foo    >"

    assert {:ok, state} = parse(data, StackHandler, [])

    assert state == [
             end_document: {},
             end_element: {nil, "foo"},
             characters: "Some data",
             start_element: {nil, "foo", []},
             start_document: []
           ]
  end

  test "handles trailing Unicode codepoints during streaming" do
    data = "<foo>𠜎𠜱𠝹𠱓</foo>"
    stream = for byte <- :binary.bin_to_list(data), do: <<byte>>

    assert {:ok, event_stack} = Sassone.parse_stream(stream, StackHandler, [])

    assert event_stack == [
             {:end_document, {}},
             {:end_element, {nil, "foo"}},
             {:characters, "𠜎𠜱𠝹𠱓"},
             {:start_element, {nil, "foo", []}},
             {:start_document, []}
           ]
  end

  test "parse_stream/4 emits characters when they reach the max length limit" do
    character_data_max_length = 32
    first_chunk = String.duplicate("x", character_data_max_length)
    second_chunk = String.duplicate("y", character_data_max_length)

    doc = String.codepoints(~s(<foo>#{first_chunk}#{second_chunk}</foo>))

    assert {:ok, state} =
             Sassone.parse_stream(doc, StackHandler, [],
               character_data_max_length: character_data_max_length
             )

    assert state == [
             end_document: {},
             end_element: {nil, "foo"},
             characters: "",
             characters: second_chunk,
             characters: first_chunk,
             start_element: {nil, "foo", []},
             start_document: []
           ]

    assert {:ok, state} = Sassone.parse_stream(doc, StackHandler, [])

    assert state == [
             end_document: {},
             end_element: {nil, "foo"},
             characters: first_chunk <> second_chunk,
             start_element: {nil, "foo", []},
             start_document: []
           ]
  end

  test "handles errors occurred during parsing" do
    data = "<?xml ?><foo/>"
    assert {:error, exception} = parse(data, StackHandler, [])
    assert Exception.message(exception) == "unexpected byte \"?\", expected token: :version"

    data = "<?xml ?><foo/>"
    assert {:error, exception} = parse(data, StackHandler, [])
    assert Exception.message(exception) == "unexpected byte \"?\", expected token: :version"

    data = "<?xml"
    assert {:error, exception} = parse(data, StackHandler, [])
    assert Exception.message(exception) == "unexpected end of input, expected token: :version"

    data = "<foo><bar></bee></foo>"
    assert {:error, exception} = parse(data, StackHandler, [])
    assert Exception.message(exception) == "unexpected ending tag \"bee\", expected tag: \"bar\""

    data = "<foo>Some data</foo    bar >"
    assert {:error, exception} = parse(data, StackHandler, [])

    assert Exception.message(exception) ==
             "unexpected ending tag \"foo   \", expected tag: \"foo\""
  end

  describe "encode!/2" do
    import Sassone.XML

    test "encodes XML document into string" do
      root = element(nil, "foo", [], "foo")
      assert Sassone.encode!(root, version: "1.0") == ~s(<?xml version="1.0"?><foo>foo</foo>)
    end
  end

  describe "encode_to_iodata!/2" do
    import Sassone.XML

    test "encodes XML document into IO data" do
      root = element(nil, "foo", [], "foo")
      assert xml = Sassone.encode_to_iodata!(root, version: "1.0")
      assert is_list(xml)
      assert IO.iodata_to_binary(xml) == ~s(<?xml version="1.0"?><foo>foo</foo>)
    end
  end

  @events [
    :start_document,
    :start_element,
    :characters,
    :end_element,
    :end_document
  ]

  for event <- @events do
    test "allows stopping the parsing process on #{inspect(event)}" do
      data = "<?xml version=\"1.0\" ?><foo>foo</foo>"
      assert_parse_stop(data, unquote(event))
    end
  end

  defp assert_parse_stop(data, stop_event) do
    value = make_ref()
    state = {stop_event, {:stop, value}}

    assert parse(data, ControlHandler, state) == {:ok, value}
  end

  describe "parser halting" do
    test "halts the parsing process and returns the rest of the binary" do
      data = "<?xml version=\"1.0\" ?><foo/>"
      assert parse_halt(data, :start_document) == "<foo/>"
      assert parse_halt(data, :start_element) == ""
      assert parse_halt(data, :end_element) == ""
      assert parse_halt(data, :end_document) == ""

      data = "<?xml version=\"1.0\" ?><foo>foo</foo>"
      assert parse_halt(data, :start_element) == "foo</foo>"
      assert parse_halt(data, :characters) == "</foo>"
      assert parse_halt(data, :end_element) == ""

      data = "<?xml version=\"1.0\" ?><foo>foo <bar/></foo>"
      assert parse_halt(data, {:start_element, {nil, "foo", []}}) == "foo <bar/></foo>"
      assert parse_halt(data, {:characters, "foo "}) == "<bar/></foo>"
      assert parse_halt(data, {:start_element, {nil, "bar", []}}) == "</foo>"
      assert parse_halt(data, {:end_element, {nil, "bar"}}) == "</foo>"
      assert parse_halt(data, {:end_element, {nil, "foo"}}) == ""
      assert parse_halt(data <> "trailing", {:end_element, {nil, "foo"}}) == "trailing"

      data = "<?xml version=\"1.0\" ?><foo><![CDATA[foo]]></foo>"
      assert parse_halt(data, {:characters, "foo"}) == "</foo>"
    end
  end

  defp parse_halt(data, halt_event) do
    value = make_ref()
    state = {halt_event, {:halt, value}}

    assert {:halt, ^value, rest} = parse(data, ControlHandler, state)

    rest
  end

  for event <- @events do
    test "errs on handler invalid returning on #{event}" do
      event = unquote(event)
      data = "<?xml version=\"1.0\" ?><foo>foo</foo>"
      value = System.unique_integer()

      assert {:error, error} = parse(data, ControlHandler, {event, value})

      assert Exception.message(error) ==
               "unexpected return #{value} in #{inspect(event)} event handler"
    end
  end

  def convert_entity("unknown"), do: "known"
end
