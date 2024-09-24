defmodule Sassone.XMLTest do
  use ExUnit.Case, async: true

  import Sassone.XML

  describe "element/3" do
    test "generates element in simple form" do
      assert element(nil, "foo", [], []) == {nil, "foo", [], []}
      assert element(nil, "foo", [{"a", 1}], []) == {nil, "foo", [{"a", 1}], []}
    end
  end

  describe "empty_element/2" do
    test "generates empty element in simple form" do
      assert empty_element(nil, "foo", []) == {nil, "foo", [], []}
      assert empty_element(nil, "foo", [{"a", 1}]) == {nil, "foo", [{"a", 1}], []}
    end
  end

  describe "characters/1" do
    test "generates characters in simple form" do
      assert characters("foo & bar") == {:characters, "foo & bar"}
      assert characters(~c"foo & bar") == {:characters, "foo & bar"}
      assert characters(:foo) == {:characters, "foo"}
    end
  end

  describe "comment/1" do
    test "generates comment in simple form" do
      assert comment("foo & bar") == {:comment, "foo & bar"}
      assert comment(~c"foo & bar") == {:comment, "foo & bar"}
      assert comment(:foo) == {:comment, "foo"}
    end
  end

  describe "cdata/1" do
    test "generates comment in simple form" do
      assert cdata("foo & bar") == {:cdata, "foo & bar"}
      assert cdata(~c"foo & bar") == {:cdata, "foo & bar"}
      assert cdata(:foo) == {:cdata, "foo"}
    end
  end

  describe "reference/2" do
    test "generates refence in simple form" do
      assert reference(:entity, "foo") == {:reference, {:entity, "foo"}}
      assert reference(:hexadecimal, 64) == {:reference, {:hexadecimal, 64}}
      assert reference(:decimal, 64) == {:reference, {:decimal, 64}}
    end
  end

  describe "processing_instruction/3" do
    test "generates refence in simple form" do
      assert processing_instruction("foo", "bar") == {:processing_instruction, "foo", "bar"}
    end
  end
end
