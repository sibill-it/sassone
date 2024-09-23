defmodule Sassone.Handler do
  @moduledoc """
  This module provides callbacks to implement SAX events handler.

  The initial `user_state` is the third argument in `Sassone.parse_string/3` and `Sassone.parse_stream/3`.
  It can be accumulated and passed around during the parsing time by returning it as the result of
  the callback implementation, which can be used to keep track of data when parsing is happening.

  Returning `{:ok, new_state}` continues the parsing process with the new state.

  Returning `{:cont, handler, new_state}` continues the parsing process with the new handler module and new state.

  Returning `{:stop, anything}` stops the prosing process immediately, and `anything` will be returned.
  This is usually handy when we want to get the desired return without parsing the whole file.

  Returning `{:halt, anything}` stops the prosing process immediately, `anything` will be returned, together
  with the rest of buffer being parsed. This is usually handy when we want to get the desired return
  without parsing the whole file.

  ## SAX Events

  There are a couple of events that need to be handled in the handler.

  * `:start_document`.
  * `:start_element`.
  * `:characters` – the binary that matches [`CharData*`](https://www.w3.org/TR/xml/#d0e1106) and [Reference](https://www.w3.org/TR/xml/#NT-Reference).
    Note that it is **not trimmed** and includes **ALL** whitespace characters that match `CharData`.
  * `:cdata` – the binary that matches [`CData*`](https://www.w3.org/TR/2006/REC-xml11-20060816/#NT-CData).
  * `:end_document`.
  * `:end_element`.

  Check out `t:data/0` type for more information of what are emitted for each event type.

  ## Examples

      defmodule MyEventHandler do
        @behaviour Sassone.Handler

        def handle_event(:start_document, prolog, state) do
          {:ok, [{:start_document, prolog} | state]}
        end

        def handle_event(:end_document, _data, state) do
          {:ok, [{:end_document} | state]}
        end

        def handle_event(:start_element, {namespace, name, attributes}, state) do
          {:ok, [{:start_element, namespace, name, attributes} | state]}
        end

        def handle_event(:end_element, {namespace, name}, state) do
          {:ok, [{:end_element, namespace, name} | state]}
        end

        def handle_event(:characters, chars, state) do
          {:ok, [{:chacters, chars} | state]}
        end
      end
  """

  alias Sassone.XML

  @type t :: module()

  @type cdata :: String.t()
  @type characters :: String.t()
  @type end_document :: state()
  @type end_element :: {XML.namespace(), XML.name()}
  @type start_element :: {XML.namespace(), XML.name(), [XML.attribute()]}
  @type start_document :: Keyword.t()

  @type event() ::
          :cdata
          | :characters
          | :end_document
          | :end_element
          | :start_document
          | :start_element

  @type data() ::
          cdata()
          | characters()
          | end_document()
          | end_element()
          | start_document()
          | start_element()

  @type state() :: any()

  @callback handle_event(event(), data(), state()) ::
              {:ok, state()}
              | {:cont, t(), state()}
              | {:stop, state()}
              | {:halt, state()}
end
