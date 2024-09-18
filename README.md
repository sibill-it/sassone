Sassone
====

[![Test suite](https://github.com/sibill-it/sassone/actions/workflows/test.yml/badge.svg)](https://github.com/sibill-it/sassone/actions/workflows/test.yml)
[![Module Version](https://img.shields.io/hexpm/v/sassone.svg)](https://hex.pm/packages/sassone)

Sassone is an XML SAX parser and encoder in Elixir that focuses on speed, usability and standard compliance.

Comply with [Extensible Markup Language (XML) 1.0 (Fifth Edition)](https://www.w3.org/TR/xml/).

## Features highlight

* An incredibly fast XML 1.0 SAX parser.
* An extremely fast XML encoder.
* Native support for streaming parsing large XML files.
* Parse XML documents into simple DOM format.
* Support quick returning in event handlers.

## Installation

Add `:sassone` to your `mix.exs`.

```elixir
def deps() do
  [
    {:sassone, "~> 1.0"}
  ]
end
```

## Overview

Full documentation is available on [HexDocs](https://hexdocs.pm/sassone/).

If you never work with a SAX parser before, please check out [this
guide][sax-guide].

### SAX parser

A SAX event handler implementation is required before starting parsing.

```elixir
defmodule MyEventHandler do
  @behaviour Sassone.Handler

  def handle_event(:start_document, prolog, state) do
    IO.inspect("Start parsing document")
    {:ok, [{:start_document, prolog} | state]}
  end

  def handle_event(:end_document, _data, state) do
    IO.inspect("Finish parsing document")
    {:ok, [{:end_document} | state]}
  end

  def handle_event(:start_element, {namespace, name, attributes}, state) do
    IO.inspect("Start parsing namespace #{namespace} element #{name} with attributes #{inspect(attributes)}")
    {:ok, [{:start_element, name, attributes} | state]}
  end

  def handle_event(:end_element, name, state) do
    IO.inspect("Finish parsing element #{name}")
    {:ok, [{:end_element, name} | state]}
  end

  def handle_event(:characters, chars, state) do
    IO.inspect("Receive characters #{chars}")
    {:ok, [{:characters, chars} | state]}
  end

  def handle_event(:cdata, cdata, state) do
    IO.inspect("Receive CData #{cdata}")
    {:ok, [{:cdata, cdata} | state]}
  end
end
```

Then start parsing XML documents with:

```elixir
iex> xml = "<?xml version='1.0' ?><foo bar='value'></foo>"
iex> Sassone.parse_string(xml, MyEventHandler, [])
{:ok,
 [{:end_document},
  {:end_element, "foo"},
  {:start_element, "foo", [{"bar", "value"}]},
  {:start_document, [version: "1.0"]}]}
```

### Streaming parsing

Sassone also accepts file stream as the input:

```elixir
stream = File.stream!("/path/to/file")

Sassone.parse_stream(stream, MyEventHandler, initial_state)
```

It even supports parsing a normal stream.

```elixir
stream = File.stream!("/path/to/file") |> Stream.filter(&(&1 != "\n"))

Sassone.parse_stream(stream, MyEventHandler, initial_state)
```

### Partial parsing

Sassone can parse an XML document partially. This feature is useful when the
document cannot be turned into a stream e.g receiving over socket.

```elixir
{:ok, partial} = Partial.new(MyEventHandler, initial_state)
{:cont, partial} = Partial.parse(partial, "<foo>")
{:cont, partial} = Partial.parse(partial, "<bar></bar>")
{:cont, partial} = Partial.parse(partial, "</foo>")
{:ok, state} = Partial.terminate(partial)
```

### XML builder

Sassone offers two APIs to build simple form and encode XML document.

Use `Sassone.XML` to build and compose XML simple form, then `Sassone.encode!/2`
to encode the built element into XML binary.

```elixir
iex> import Sassone.XML
iex> element = element("person", [gender: "female"], "Alice")
{"person", [{"gender", "female"}], [{:characters, "Alice"}]}
iex> Sassone.encode!(element, [])
"<?xml version=\"1.0\"?><person gender=\"female\">Alice</person>"
```

See `Sassone.XML` for more XML building APIs.

Sassone also provides `Sassone.Builder` protocol to help composing structs into simple form.

```elixir
defmodule Person do
  @derive {Sassone.Builder, name: "person", attributes: [:gender], children: [:name]}

  defstruct [:gender, :name]
end

iex> jack = %Person{gender: :male, name: "Jack"}
iex> john = %Person{gender: :male, name: "John"}
iex> import Sassone.XML
iex> root = element("people", [], [jack, john])
iex> Sassone.encode!(root, [])
"<?xml version=\"1.0\"?><people><person gender=\"male\">Jack</person><person gender=\"male\">John</person></people>"
```

## FAQs with Sassone/XMLs

### Sassone sounds cool! But I just wanted to quickly convert some XMLs into maps/JSON...

Sassone does not have offer XML to maps conversion, because many awesome people
already made it happen 💪:

* https://github.com/bennyhat/xml_json
* https://github.com/xinz/sax_map

Alternatively, this [pull request](https://github.com/qcam/saxy/pull/78) could
serve as a good reference if you want to implement your own map-based handler.

### Does Sassone work with XPath?

Sassone in its core is a SAX parser, therefore Sassone does not, and likely will
not, offer any XPath functionality.

[SweetXml][sweet_xml] is a wonderful library to work with XPath. However,
`:xmerl`, the library used by SweetXml, is not always memory efficient and
speedy. You can combine the best of both sides with [Saxmerl][saxmerl], which
is a Sassone extension converting XML documents into SweetXml compatible format.
Please check that library out for more information.

### Sassone! Where did the name come from?

![Sa xi Chuong Duong](./assets/saxi.jpg)

Sa Xi, pronounced like `sa-see`, is an awesome soft drink made by [Chuong Duong](http://www.cdbeco.com.vn/en).

## Benchmarking

Note that benchmarking XML parsers is difficult and highly depends on the complexity
of the documents being parsed. Event I try hard to make the benchmarking suite
fair but it's hard to avoid biases when choosing the documents to benchmark
against.

Therefore the conclusion in this section is only for reference purpose. Please
feel free to benchmark against your target documents. The benchmark suite can be found
in [bench/](https://github.com/sibill-it/sassone/tree/master/bench).

A rule of thumb is that we should compare apple to apple. Some XML parsers
target only specific types of XML. Therefore some indicators are provided in the
test suite to let know of the fairness of the benchmark results.

Some quick and biased conclusions from the benchmark suite:

* For SAX parser, Sassone is usually 1.4 times faster than [Erlsom](https://github.com/willemdj/erlsom).
  With deeply nested documents, Sassone is noticeably faster (4 times faster).
* For XML builder and encoding, Sassone is usually 10 to 30 times faster than [XML Builder](https://github.com/joshnuss/xml_builder).
  With deeply nested documents, it could be 180 times faster.
* Sassone significantly uses less memory than XML Builder (4 times to 25 times).
* Sassone significantly uses less memory than Xmerl, Erlsom and Exomler (1.4 times
  10 times).

## Limitations

* No XSD supported.
* No DTD supported, when Sassone encounters a `<!DOCTYPE`, it skips that.
* Only support UTF-8 encoding.

## Contributing

If you have any issues or ideas, feel free to write to https://github.com/sibill-it/sassone/issues.

To start developing:

1. Fork the repository.
2. Write your code and related tests.
3. Create a pull request at https://github.com/sibill-it/sassone/pulls.

## Copyright and License

Copyright (c) 2018 Cẩm Huỳnh

This software is licensed under [the MIT license](./LICENSE.md).

[saxmerl]: https://github.com/qcam/saxmerl
[sweet_xml]: https://github.com/kbrw/sweet_xml
[sax-guide]: https://hexdocs.pm/sassone/getting-started-with-sax.html
