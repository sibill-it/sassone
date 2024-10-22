defmodule Sassone.BuilderTest do
  use ExUnit.Case, async: true

  alias Sassone.Builder
  alias Sassone.TestSchemas.Person

  describe "building" do
    test "encode simple schema" do
      alice = %Person{gender: "female", name: "Alice", surname: "Cooper", bio: "A nice girl."}

      assert ~s|<person gender="female">A nice girl.<name>Alice</name><surname>Cooper</surname></person>| =
               Builder.build(alice)
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
      assert attrs.bio == "A friendly mate."
    end
  end
end
