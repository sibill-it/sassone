defmodule Sassone.Parser.ElementTest do
  use SassoneTest.ParsingCase, async: true
  use ExUnitProperties

  alias Sassone.TestHandlers.StackHandler

  test "parses element having no attributes" do
    events = assert_parse("<foo></foo>")

    assert events == [
             {:start_element, {nil, "foo", []}},
             {:end_element, {nil, "foo"}}
           ]

    assert_parse("<cổc></cổc>")
  end

  test "parses element having namespaces" do
    assert assert_parse("<ns:foo></ns:foo>") == [
             {:start_element, {"ns", "foo", []}},
             {:end_element, {"ns", "foo"}}
           ]
  end

  test "parses element with nested children" do
    buffer =
      remove_indents("""
      <item name="[日本語] Tom &amp; Jerry" category='movie' >
        <author name='William Hanna &#x26; Joseph Barbera' />
        <!--Ignore me please I am just a comment-->
        <?foo Hmm? Then probably ignore me too?>
        <description><![CDATA[<strong>"Tom & Jerry" is a cool movie!</strong>]]></description>
        <actors>
          <actor>Tom</actor>
          <actor>Jerry</actor>
        </actors>
      </item>
      <!--a very bottom comment-->
      <?foo what a instruction ?>
      """)

    events = assert_parse(buffer, cdata_as_characters: false)

    item_attributes = [{"name", "[日本語] Tom & Jerry"}, {"category", "movie"}]
    assert [{:start_element, {nil, "item", ^item_attributes}} | events] = events

    author_attributes = [{"name", "William Hanna & Joseph Barbera"}]
    assert [{:start_element, {nil, "author", ^author_attributes}} | events] = events
    assert [{:end_element, {nil, "author"}} | events] = events

    assert [{:start_element, {nil, "description", []}} | events] = events
    assert [{:cdata, "<strong>\"Tom & Jerry\" is a cool movie!</strong>"} | events] = events
    assert [{:end_element, {nil, "description"}} | events] = events

    assert [{:start_element, {nil, "actors", []}} | events] = events
    assert [{:start_element, {nil, "actor", []}} | events] = events
    assert [{:characters, "Tom"} | events] = events
    assert [{:end_element, {nil, "actor"}} | events] = events
    assert [{:start_element, {nil, "actor", []}} | events] = events
    assert [{:characters, "Jerry"} | events] = events
    assert [{:end_element, {nil, "actor"}} | events] = events
    assert [{:end_element, {nil, "actors"}} | events] = events

    assert [{:end_element, {nil, "item"}} | events] = events

    assert events == []
  end

  test "parses empty element" do
    buffer = "<foo />"

    events = assert_parse(buffer)

    assert events == [
             {:start_element, {nil, "foo", []}},
             {:end_element, {nil, "foo"}}
           ]

    buffer = "<foo foo='FOO' bar='BAR'/>"

    events = assert_parse(buffer)

    element = {nil, "foo", [{"foo", "FOO"}, {"bar", "BAR"}]}

    assert events == [
             {:start_element, element},
             {:end_element, {nil, "foo"}}
           ]

    buffer = "<foo foo='Tom &amp; Jerry' bar='bar' />"

    events = assert_parse(buffer)
    element = {nil, "foo", [{"foo", "Tom & Jerry"}, {"bar", "bar"}]}

    assert events == [
             {:start_element, element},
             {:end_element, {nil, "foo"}}
           ]
  end

  test "parses element content" do
    buffer = "<foo>Lorem Ipsum Lorem Ipsum</foo>"

    events = assert_parse(buffer)

    assert events == [
             {:start_element, {nil, "foo", []}},
             {:characters, "Lorem Ipsum Lorem Ipsum"},
             {:end_element, {nil, "foo"}}
           ]

    buffer = """
    <foo>
    Lorem Ipsum Lorem Ipsum
    </foo>
    """

    events = assert_parse(buffer)

    assert events == [
             {:start_element, {nil, "foo", []}},
             {:characters, "\nLorem Ipsum Lorem Ipsum\n"},
             {:end_element, {nil, "foo"}}
           ]

    events = assert_parse("<foo>  </foo>")

    assert events == [
             {:start_element, {nil, "foo", []}},
             {:characters, "  "},
             {:end_element, {nil, "foo"}}
           ]
  end

  test "parses comments" do
    assert_parse("<foo><!--IGNORE ME--></foo>")
  end

  test "handles malformed comments" do
    error = refute_parse("<foo><!--IGNORE ME---></foo>")
    assert Exception.message(error) == "unexpected byte \"-\", expected token: :comment"

    refute_parse("<foo><!--IGNORE ME")
  end

  test "parses element references" do
    events = assert_parse("<foo>Tom &#x26; Jerry</foo>")
    assert find_event(events, :characters, "Tom & Jerry")

    events = assert_parse("<foo>Tom &#38; Jerry</foo>")
    assert find_event(events, :characters, "Tom & Jerry")

    events = assert_parse("<foo>Tom &amp; Jerry</foo>")
    assert find_event(events, :characters, "Tom & Jerry")
  end

  test "handles malformed references in element" do
    error = refute_parse("<foo>Tom &#xt5; Jerry</foo>")
    assert Exception.message(error) == "unexpected byte \"t\", expected token: :char_ref"

    error = refute_parse("<foo>Tom &#t5; Jerry</foo>")
    assert Exception.message(error) == "unexpected byte \"t\", expected token: :char_ref"

    error = refute_parse("<foo>Tom &t5 Jerry</foo>")
    assert Exception.message(error) == "unexpected byte \" \", expected token: :entity_ref"
  end

  test "malformed misc in the end of the document" do
    error = refute_parse("<foo/>bar")
    assert Exception.message(error) == "unexpected byte \"b\", expected token: :misc"

    error = refute_parse("<foo/><_")
    assert Exception.message(error) == "unexpected byte \"_\", expected token: :misc"
  end

  test "parses CDATA" do
    events = assert_parse("<foo><![CDATA[John Cena <foo></foo> &amp;]]></foo>")
    assert find_events(events, :characters) == [{:characters, "John Cena <foo></foo> &amp;"}]

    events =
      assert_parse("<foo><![CDATA[John Cena <foo></foo> &amp;]]></foo>",
        cdata_as_characters: false
      )

    assert find_events(events, :cdata) == [{:cdata, "John Cena <foo></foo> &amp;"}]
  end

  test "handles malformed CDATA" do
    error = refute_parse("<foo><![CDATA[John Cena </foo>")
    assert Exception.message(error) == "unexpected end of input, expected token: :\"]]\""
  end

  test "parses processing instruction" do
    events = assert_parse("<foo><?hello the instruction?></foo>")
    assert length(events) == 2

    assert_parse("<foo><?ổ instruction?></foo>")
    assert_parse("<foo><?cổ instruction?></foo>")
    assert_parse("<foo/><?ổ instruction?>")
    assert_parse("<foo/><?cổ instruction?>")
  end

  test "handles malformed processing instruction" do
    error = refute_parse("<foo><?hello the instruction")

    assert Exception.message(error) ==
             "unexpected end of input, expected token: :processing_instruction"
  end

  test "parses element attributes" do
    events = assert_parse("<foo abc='123' def=\"456\" g:hi='789' />")
    tag = {nil, "foo", [{"abc", "123"}, {"def", "456"}, {"g:hi", "789"}]}
    assert find_event(events, :start_element, tag)
    assert find_event(events, :end_element, {nil, "foo"})

    events = assert_parse(~s(<foo abc = "ABC" />))
    tag = {nil, "foo", [{"abc", "ABC"}]}
    assert find_event(events, :start_element, tag)
    assert find_event(events, :end_element, {nil, "foo"})

    events = assert_parse(~s(<foo val="Tom &#x26; Jerry" />))
    assert find_event(events, :start_element, {nil, "foo", [{"val", "Tom & Jerry"}]})
    assert find_event(events, :end_element, {nil, "foo"})

    error = refute_parse(~s(<foo val="Tom &#x26 Jerry" />))
    assert Exception.message(error) == "unexpected byte \" \", expected token: :char_ref"

    events = assert_parse(~s(<foo val="Tom &#38; Jerry" />))
    assert find_event(events, :start_element, {nil, "foo", [{"val", "Tom & Jerry"}]})
    assert find_event(events, :end_element, {nil, "foo"})

    error = refute_parse(~s(<foo val="Tom &#38 Jerry" />))
    assert Exception.message(error) == "unexpected byte \" \", expected token: :char_ref"

    events = assert_parse(~s(<foo val="Tom &amp; Jerry" />))
    assert find_event(events, :start_element, {nil, "foo", [{"val", "Tom & Jerry"}]})
    assert find_event(events, :end_element, {nil, "foo"})
  end

  @tag :property

  property "element name" do
    check all(name <- name()) do
      events = assert_parse("<#{name}></#{name}>")

      assert events == [{:start_element, {nil, name, []}}, {:end_element, {nil, name}}]
    end

    check all(name <- name()) do
      events = assert_parse("<#{name}/>")

      assert events == [{:start_element, {nil, name, []}}, {:end_element, {nil, name}}]
    end
  end

  property "attribute name" do
    check all(attribute_name <- name()) do
      events = assert_parse("<foo #{attribute_name}='bar'></foo>")

      assert events == [
               {:start_element, {nil, "foo", [{attribute_name, "bar"}]}},
               {:end_element, {nil, "foo"}}
             ]
    end
  end

  property "attribute value" do
    reference_generator =
      gen all(name <- name()) do
        "&" <> name <> ";"
      end

    check all(
            attribute_value_chars <- string(:alphanumeric),
            reference <- reference_generator
          ) do
      attribute_value =
        [attribute_value_chars, reference]
        |> Enum.shuffle()
        |> IO.iodata_to_binary()

      events = assert_parse("<foo foo='#{attribute_value}'></foo>")
      element = {nil, "foo", [{"foo", attribute_value}]}

      assert events == [{:start_element, element}, {:end_element, {nil, "foo"}}]
    end
  end

  defp find_events(events, event_type) do
    Enum.filter(events, fn {type, _data} -> type == event_type end)
  end

  defp find_event(events, event_type, event_data) do
    Enum.find(events, fn {type, data} ->
      type == event_type && data == event_data
    end)
  end

  @name_start_char_ranges [
    ?:,
    ?_,
    ?A..?Z,
    ?a..?z,
    0xC0..0xD6,
    0xD8..0xF6,
    0xF8..0x2FF,
    0x370..0x37D,
    0x37F..0x1FFF,
    0x200C..0x200D,
    0x2070..0x218F,
    0x2C00..0x2FEF,
    0x3001..0xD7FF,
    0xF900..0xFDCF,
    0xFDF0..0xFFFD,
    0x10000..0xEFFFF
  ]

  @name_char_ranges @name_start_char_ranges ++
                      [
                        ?0..?9,
                        ?-,
                        ?.,
                        0xB7,
                        0x0300..0x036F,
                        0x203F..0x2040
                      ]

  defp name do
    gen all(
          start_char <- string(@name_start_char_ranges, min_length: 1, max_length: 4),
          chars <- string(@name_char_ranges)
        ) do
      start_char <> chars
    end
  end

  defp refute_parse(data, options \\ []) do
    assert {:error, error} = Sassone.parse_string(data, StackHandler, [], options)

    stream = for <<char <- data>>, do: <<char>>
    assert {:error, _} = Sassone.parse_stream(stream, StackHandler, [], options)

    error
  end

  defp assert_parse(data, options \\ []) do
    assert {:ok, events} = Sassone.parse_string(data, StackHandler, [], options)

    stream = for <<char <- data>>, do: <<char>>
    assert Sassone.parse_stream(stream, StackHandler, [], options) == {:ok, events}

    assert [{:end_document, {}} | events] = events
    assert [{:start_document, []} | events] = Enum.reverse(events)

    events
  end
end
