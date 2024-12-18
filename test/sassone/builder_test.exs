defmodule Sassone.BuilderTest do
  use ExUnit.Case, async: true

  alias Sassone.Builder
  alias Sassone.TestSchemas.{Order, Person}

  describe "building" do
    test "encode simple schema" do
      assert ~s|<person gender="female"><name>Alice</name><surname>Cooper</surname>A nice girl.</person>| =
               Builder.build(%Person{
                 gender: "female",
                 name: "Alice",
                 surname: "Cooper",
                 bio: "A nice girl."
               })
               |> Sassone.encode!()
    end
  end

  describe "parsing" do
    test "decode simple schema" do
      assert {:ok, {struct, attrs}} =
               Sassone.parse_string(
                 ~s|<person gender="male"><name>Bob</name><surname>Price</surname>A friendly mate.</person>|,
                 Builder.handler(%Person{}),
                 nil
               )

      assert Person == struct
      assert attrs.gender == "male"
      assert attrs.name == "Bob"
      assert attrs.surname == "Price"
    end

    test "decode nested schema with single item" do
      assert {:ok, {struct, attrs}} =
               Sassone.parse_string(
                 ~s|<order id="0193d966-d700-7e86-b290-d3c0fb597ffe"><line sorting="asc"><product uuid="0193d967-2a09-7206-839c-cc85df884f3d"><name>test</name></product><quantity>1.0</quantity></line><status>new</status><ref>order-ref-id</ref></order>|,
                 Builder.handler(%Order{}),
                 nil
               )

      assert Order == struct
      assert attrs.id == "0193d966-d700-7e86-b290-d3c0fb597ffe"

      assert attrs.line == [
               %{
                 product: %{name: "test", uuid: "0193d967-2a09-7206-839c-cc85df884f3d"},
                 quantity: "1.0",
                 sorting: "asc"
               }
             ]

      assert attrs.status == "new"
      assert attrs.ref == "order-ref-id"
    end
  end

  test "decode nested schema with multiple items" do
    assert {:ok, {struct, attrs}} =
             Sassone.parse_string(
               ~s|<order id="1"><line sorting="asc"><product uuid="1"><name>test</name></product><quantity>1.0</quantity></line><line sorting="desc"><product uuid="2"><name>test</name></product><quantity>1.0</quantity></line><status>new</status><ref>order-ref-id</ref></order>|,
               Builder.handler(%Order{}),
               nil
             )

    assert Order == struct
    assert attrs.id == "1"

    assert attrs.line == [
             %{
               product: %{name: "test", uuid: "1"},
               quantity: "1.0",
               sorting: "asc"
             },
             %{
               product: %{name: "test", uuid: "2"},
               quantity: "1.0",
               sorting: "desc"
             }
           ]

    assert attrs.status == "new"
    assert attrs.ref == "order-ref-id"
  end
end
