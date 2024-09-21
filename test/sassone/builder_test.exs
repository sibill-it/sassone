defmodule Sassone.BuilderTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Sassone.Builder, only: [build: 1]
  import Sassone.XML

  doctest Sassone.Builder

  test "builds pre-built simple-form element" do
    element = element(nil, :foo, [], [])
    assert build(element) == element

    element = empty_element(nil, :foo, [])
    assert build(element) == element

    characters = characters("foo")
    assert build(characters) == characters

    cdata = cdata("foo")
    assert build(cdata) == cdata

    reference = reference(:entity, "foo")
    assert build(reference) == reference

    comment = comment("foo")
    assert build(comment) == comment

    assert_raise Protocol.UndefinedError, fn -> build({}) end
  end

  test "builds datetime" do
    date = ~D[2018-03-01]
    assert build(date) == {:characters, "2018-03-01"}

    time = ~T[20:18:11.023]
    assert build(time) == {:characters, "20:18:11.023"}

    {:ok, naive_datetime} = NaiveDateTime.new(~D[2018-01-01], ~T[23:04:00.005])
    assert build(naive_datetime) == {:characters, "2018-01-01T23:04:00.005"}

    datetime = DateTime.utc_now()
    assert build(datetime) == {:characters, DateTime.to_iso8601(datetime)}
  end

  test "builds element from struct" do
    struct = %Struct{foo: "foo", bar: "bar"}
    assert build(struct) == {nil, "test", [{"foo", "foo"}], ["bar"]}

    nested_struct = %Struct{bar: struct}

    assert build(nested_struct) ==
             {nil, "test", [{"foo", ""}], [{nil, "test", [{"foo", "foo"}], ["bar"]}]}

    underived_struct = %UnderivedStruct{}
    assert_raise Protocol.UndefinedError, fn -> build(underived_struct) end
  end

  test "builds structs with custom transformer" do
    post = %Post{
      categories: [
        %Category{name: "foo"},
        %Category{name: "bar"}
      ]
    }

    assert build(post) == {
             nil,
             "post",
             [],
             [
               {nil, "category", [{"name", "foo"}], []},
               {nil, "category", [{"name", "bar"}], []},
               {nil, "cats", [],
                [
                  {nil, "category", [{"name", "foo"}], []},
                  {nil, "category", [{"name", "bar"}], []}
                ]},
               {nil, "categories", [],
                [
                  {nil, "category", [{"name", "foo"}], []},
                  {nil, "category", [{"name", "bar"}], []}
                ]}
             ]
           }
  end

  @tag :property

  property "number" do
    check all(integer <- integer()) do
      assert build(integer) == {:characters, Integer.to_string(integer)}
    end

    check all(float <- float()) do
      assert build(float) == {:characters, Float.to_string(float)}
    end
  end

  property "bitstring" do
    check all(string <- string(:printable)) do
      assert build(string) == {:characters, string}
    end
  end

  property "atom" do
    assert build(nil) == ""

    check all(atom <- atom(:alphanumeric)) do
      assert build(atom) == {:characters, Atom.to_string(atom)}
    end
  end
end
