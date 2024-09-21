defmodule Sassone.Encoder do
  @moduledoc false

  alias Sassone.Prolog

  def encode_to_iodata(root, prolog) do
    prolog = prolog(prolog)
    element = element(root)

    [prolog | element]
  end

  defp prolog(%Prolog{} = prolog) do
    [
      ~c"<?xml",
      version(prolog.version),
      encoding(prolog.encoding),
      standalone(prolog.standalone),
      ~c"?>"
    ]
  end

  defp prolog(prolog) when is_list(prolog) do
    prolog
    |> Prolog.from_keyword()
    |> prolog()
  end

  defp prolog(nil), do: []

  defp version(version), do: [?\s, ~c"version", ?=, ?", version, ?"]

  defp encoding(nil), do: []
  defp encoding(:utf8), do: [?\s, ~c"encoding", ?=, ?", ~c"utf-8", ?"]

  defp encoding(encoding) when encoding in ["UTF-8", "utf-8"],
    do: [?\s, ~c"encoding", ?=, ?", ~c(#{encoding}), ?"]

  defp standalone(true), do: [?\s, ~c"standalone", ?=, ?", "yes", ?"]
  defp standalone(_standalone), do: []

  defp element({ns, tag_name, attributes, []}), do: [start_tag(ns, tag_name, attributes), ?/, ?>]

  defp element({ns, tag_name, attributes, content}) do
    [
      start_tag(ns, tag_name, attributes),
      ?>,
      content(content),
      end_tag(ns, tag_name, content)
    ]
  end

  defp start_tag(nil, tag_name, attributes), do: [?<, tag_name | attributes(attributes)]
  defp start_tag(ns, tag_name, attributes), do: [?<, ns, ?:, tag_name | attributes(attributes)]

  defp attributes([]), do: []

  defp attributes([{name, value} | attributes]),
    do: [?\s, name, ?=, ?", escape(value, 0, value), ?" | attributes(attributes)]

  defp content([]), do: []

  defp content([{:characters, characters} | elements]) do
    [characters(characters) | content(elements)]
  end

  defp content([{:cdata, cdata} | elements]) do
    [cdata(cdata) | content(elements)]
  end

  defp content([{:reference, reference} | elements]) do
    [reference(reference) | content(elements)]
  end

  defp content([{:comment, comment} | elements]) do
    [comment(comment) | content(elements)]
  end

  defp content([{:processing_instruction, name, content} | elements]) do
    [processing_instruction(name, content) | content(elements)]
  end

  defp content([characters | elements]) when is_binary(characters) do
    [characters | content(elements)]
  end

  defp content([element | elements]) do
    [element(element) | content(elements)]
  end

  defp end_tag(nil, tag_name, _other), do: [?<, ?/, tag_name, ?>]
  defp end_tag(ns, tag_name, _other), do: [?<, ?/, ns, ?:, tag_name, ?>]

  defp characters(characters), do: escape(characters, 0, characters)

  escapes = [{?<, ~c"&lt;"}, {?>, ~c"&gt;"}, {?&, ~c"&amp;"}, {?", ~c"&quot;"}, {?', ~c"&apos;"}]

  for {match, insert} <- escapes do
    defp escape(<<unquote(match), rest::bits>>, len, original),
      do: [binary_part(original, 0, len), unquote(insert) | escape(rest, 0, rest)]
  end

  defp escape(<<>>, _len, original), do: original

  defp escape(<<_, rest::bits>>, len, original), do: escape(rest, len + 1, original)

  defp cdata(characters), do: [~c"<![CDATA[", characters | ~c"]]>"]

  defp reference({:entity, reference}), do: [?&, reference, ?;]
  defp reference({:hexadecimal, reference}), do: [?&, ?x, Integer.to_string(reference, 16), ?;]
  defp reference({:decimal, reference}), do: [?&, ?x, Integer.to_string(reference, 10), ?;]

  defp comment(comment), do: [~c"<!--", escape_comment(comment, comment) | ~c"-->"]

  defp escape_comment(<<?->>, original), do: [original, ?\s]
  defp escape_comment(<<>>, original), do: original
  defp escape_comment(<<_char, rest::bits>>, original), do: escape_comment(rest, original)

  defp processing_instruction(name, content), do: [~c"<?", name, ?\s, content | ~c"?>"]
end
