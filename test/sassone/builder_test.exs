defmodule Sassone.BuilderTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Sassone.Builder, only: [build: 1]

  doctest Sassone.Builder

  test "builds pre-built simple-form element" do
    element = Sassone.XML.element(:foo, [], [])
    assert build(element) == element

    element = Sassone.XML.empty_element(:foo, [])
    assert build(element) == element

    characters = Sassone.XML.characters("foo")
    assert build(characters) == characters

    cdata = Sassone.XML.cdata("foo")
    assert build(cdata) == cdata

    reference = Sassone.XML.reference(:entity, "foo")
    assert build(reference) == reference

    comment = Sassone.XML.comment("foo")
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

  defmodule Struct do
    @derive {Sassone.Builder, name: :test, attributes: [:foo], children: [:bar]}

    defstruct [:foo, :bar]
  end

  defmodule UnderivedStruct do
    defstruct [:foo, :bar]
  end

  test "builds element from struct" do
    struct = %Struct{foo: "foo", bar: "bar"}
    assert build(struct) == {"test", [{"foo", "foo"}], ["bar"]}

    nested_struct = %Struct{bar: struct}

    assert build(nested_struct) == {"test", [{"foo", ""}], [{"test", [{"foo", "foo"}], ["bar"]}]}

    underived_struct = %UnderivedStruct{}
    assert_raise Protocol.UndefinedError, fn -> build(underived_struct) end
  end

  defmodule Post do
    @derive {Sassone.Builder,
             name: :post,
             children: [
               :categories,
               categories: &__MODULE__.build_cats/1,
               categories: {__MODULE__, :build_categories}
             ]}

    defstruct [:categories]

    def build_categories(categories) do
      import Sassone.XML

      element("categories", [], categories)
    end

    def build_cats(categories) do
      import Sassone.XML

      element("cats", [], categories)
    end
  end

  defmodule Category do
    @derive {Sassone.Builder, name: :category, attributes: [:name]}

    defstruct [:name]
  end

  test "builds structs with custom transformer" do
    post = %Post{
      categories: [
        %Category{name: "foo"},
        %Category{name: "bar"}
      ]
    }

    assert build(post) == {
             "post",
             [],
             [
               {"category", [{"name", "foo"}], []},
               {"category", [{"name", "bar"}], []},
               {"cats", [],
                [{"category", [{"name", "foo"}], []}, {"category", [{"name", "bar"}], []}]},
               {"categories", [],
                [{"category", [{"name", "foo"}], []}, {"category", [{"name", "bar"}], []}]}
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
