defmodule Sassone.BuilderTest do
  use ExUnit.Case, async: true

  alias Sassone.Builder
  alias Sassone.TestSchemas.{AttributeEnvelope, AttributeRecord, Order, Person}

  describe "building" do
    test "encode simple schema" do
      assert ~s|<person gender="female"><name>Alice</name><surname>Cooper</surname>A nice girl.</person>| =
               Sassone.XML.build(%Person{
                 gender: "female",
                 name: "Alice",
                 surname: "Cooper",
                 bio: "A nice girl."
               })
               |> Sassone.encode!()
    end
  end

  describe "parsing" do
    test "honors parse: false for attributes without disabling their serialization" do
      xml = Sassone.XML.build(%AttributeRecord{id: "1", ignored: "build-only"})
      assert {nil, "record", attributes, []} = xml
      assert {nil, "ignored", "build-only"} in attributes

      expected = %{id: "1"}

      assert {:ok, {AttributeRecord, ^expected}} =
               Sassone.parse_string(
                 Sassone.encode!(xml),
                 Builder.handler(%AttributeRecord{}),
                 nil
               )
    end

    test "matches attribute names and namespaces regardless of attribute order" do
      for attributes <- [
            ~s|id="local" foreign:id="remote" other:id="other"|,
            ~s|other:id="other" foreign:id="remote" id="local"|
          ] do
        xml = ~s|<record xmlns:foreign="urn:foreign" xmlns:other="urn:other" #{attributes}/>|

        expected = %{id: "local", foreign_id: "remote"}

        assert {:ok, {AttributeRecord, ^expected}} =
                 Sassone.parse_string(xml, Builder.handler(%AttributeRecord{}), nil)
      end
    end

    test "does not populate a field from an attribute in another namespace" do
      xml = ~s|<record xmlns:other="urn:other" other:id="other" ignored="skip"/>|

      expected = %{}

      assert {:ok, {AttributeRecord, ^expected}} =
               Sassone.parse_string(xml, Builder.handler(%AttributeRecord{}), nil)
    end

    test "honors attribute field options in nested records while streaming" do
      xml = """
      <envelope xmlns:foreign="urn:foreign">
        <record foreign:id="single-remote" id="single-local" ignored="skip"/>
        <entry id="first-local" foreign:id="first-remote" ignored="skip"/>
        <entry foreign:id="second-remote" id="second-local" ignored="skip"/>
      </envelope>
      """

      expected =
        {:ok,
         {AttributeEnvelope,
          %{
            record: %{id: "single-local", foreign_id: "single-remote"},
            records: [
              %{id: "first-local", foreign_id: "first-remote"},
              %{id: "second-local", foreign_id: "second-remote"}
            ]
          }}}

      handler = Builder.handler(%AttributeEnvelope{})
      assert Sassone.parse_string(xml, handler, nil) == expected
      assert Sassone.parse_stream(String.graphemes(xml), handler, nil) == expected
    end

    test "decode simple schema" do
      assert {:ok, {struct, attrs}} =
               Sassone.parse_string(
                 ~s|<person gender="male">
                      <name>Bob</name>
                      <surname>Price</surname>
                      A friendly mate.
                      <no>sense</no>
                    </person>|,
                 Builder.handler(%Person{}),
                 nil
               )

      assert struct == Person
      assert attrs.gender == "male"
      assert attrs.name == "Bob"
      assert attrs.surname == "Price"
      assert attrs.bio == "A friendly mate."
    end

    test "decode nested schema with single item" do
      assert {:ok, {struct, attrs}} =
               Sassone.parse_string(
                 ~s|<order id="0193d966-d700-7e86-b290-d3c0fb597ffe">
                      <line sorting="asc">
                        <product uuid="0193d967-2a09-7206-839c-cc85df884f3d">
                          <name>test</name>
                          Description.
                        </product>
                        <quantity>1.0</quantity>
                      </line>
                      <status>new</status>
                      <ref>order-ref-id</ref>
                    </order>|,
                 Builder.handler(%Order{}),
                 nil
               )

      assert struct == Order
      assert attrs.id == "0193d966-d700-7e86-b290-d3c0fb597ffe"
      assert attrs.status == "new"
      assert attrs.ref == "order-ref-id"

      assert line = Enum.at(attrs.lines, 0)
      assert line.product.name == "test"
      assert line.product.description == "Description."
      assert line.product.uuid == "0193d967-2a09-7206-839c-cc85df884f3d"
      assert line.quantity == "1.0"
      assert line.sorting == "asc"
    end
  end

  test "decode nested schema with multiple items" do
    assert {:ok, {struct, attrs}} =
             Sassone.parse_string(
               ~s|<order id="1">
                    <line sorting="asc">
                      <product uuid="1">
                        <name>test 1</name>
                        Description 1.
                      </product>
                      <quantity>1.0</quantity>
                    </line>
                    <line sorting="desc">
                      <product uuid="2">
                        <name>test 2</name>
                        Description 2.
                      </product>
                      <quantity>2.0</quantity>
                    </line>
                    <status>new</status>
                    <ref>order-ref-id</ref>
                  </order>|,
               Builder.handler(%Order{}),
               nil
             )

    assert struct == Order
    assert attrs.id == "1"
    assert attrs.status == "new"
    assert attrs.ref == "order-ref-id"

    assert line1 = Enum.at(attrs.lines, 0)
    assert line1.product.name == "test 1"
    assert line1.product.description == "Description 1."
    assert line1.product.uuid == "1"
    assert line1.quantity == "1.0"
    assert line1.sorting == "asc"

    assert line2 = Enum.at(attrs.lines, 1)
    assert line2.product.name == "test 2"
    assert line2.product.description == "Description 2."
    assert line2.product.uuid == "2"
    assert line2.quantity == "2.0"
    assert line2.sorting == "desc"
  end
end
