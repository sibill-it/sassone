defmodule Sassone.Partial do
  @moduledoc ~S"""
  Supports parsing an XML document partially. This module is useful when
  the XML document cannot be turned into a `Stream` e.g over sockets.

  ## Example

      iex> {:ok, partial} = Sassone.Partial.new(StackHandler, [])
      iex> {:cont, partial} = Sassone.Partial.parse(partial, "<foo>")
      iex> {:cont, partial} = Sassone.Partial.parse(partial, "</foo>")
      iex> Sassone.Partial.terminate(partial)
      {:ok,
       [
         end_document: {},
         end_element: {nil, "foo"},
         start_element: {nil, "foo", []},
         start_document: []
       ]}

  """

  alias Sassone.{Handler, Parser}
  alias Sassone.Parser.State

  @opaque t() :: %__MODULE__{context_fun: function(), state: term()}
  @enforce_keys [:context_fun, :state]
  defstruct @enforce_keys

  @doc "Builds up a `Sassone.Partial`, which can be used for later parsing."
  @spec new(Handler.t(), Handler.state(), options :: Keyword.t()) ::
          {:ok, partial :: t()} | {:error, exception :: Sassone.ParseError.t()}

  def new(handler, initial_state, options \\ [])
      when is_atom(handler) do
    state = %State{
      prolog: nil,
      handler: handler,
      user_state: initial_state,
      expand_entity: options[:expand_entity] || :keep,
      cdata_as_characters: Keyword.get(options, :cdata_as_characters, true),
      character_data_max_length: options[:character_data_max_length] || :infinity
    }

    with {:halted, context_fun, state} <- Parser.Stream.parse_prolog(<<>>, true, <<>>, 0, state) do
      {:ok, %__MODULE__{context_fun: context_fun, state: state}}
    end
  end

  @doc """
  Continue parsing next chunk of the document with a partial.

  This function can return in 3 ways:

  * `{:cont, partial}` - The parsing process has not been terminated.
  * `{:halt, user_state}` - The parsing process has been terminated, usually because of parser stopping.
  * `{:halt, user_state, rest}` - The parsing process has been terminated, usually because of parser halting.
  * `{:error, exception}` - The parsing process has erred.

  """

  @spec parse(
          partial :: t(),
          data :: binary
        ) ::
          {:cont, partial :: t()}
          | {:halt, state :: term()}
          | {:halt, state :: term(), rest :: binary()}
          | {:error, exception :: Sassone.ParseError.t()}

  def parse(%__MODULE__{context_fun: context_fun, state: state} = partial, data)
      when is_binary(data) do
    case context_fun.(data, true, state) do
      {:halted, context_fun, state} ->
        {:cont, %{partial | context_fun: context_fun, state: state}}

      {:ok, state} ->
        {:halt, state.user_state}

      {:halt, state, {buffer, pos}} ->
        rest = binary_part(buffer, pos, byte_size(buffer) - pos)
        {:halt, state.user_state, rest}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Same as partial/2, but continue previous parsing with a new, provided state
  as the third argument instead of the previous accumulated state.

  i.e.
  `Sassone.Partial.parse(partial, binary, new_state) # coninue previous partial with a new state`

  This function can return in 3 ways:

  * `{:cont, partial}` - The parsing process has not been terminated.
  * `{:halt, user_state}` - The parsing process has been terminated, usually because of parser stopping.
  * `{:halt, user_state, rest}` - The parsing process has been terminated, usually because of parser halting.
  * `{:error, exception}` - The parsing process has erred.

  """
  @spec parse(
          partial :: t(),
          data :: binary,
          user_state :: term()
        ) ::
          {:cont, partial :: t()}
          | {:halt, state :: term()}
          | {:halt, state :: term(), rest :: binary()}
          | {:error, exception :: Sassone.ParseError.t()}

  def parse(%__MODULE__{} = partial, data, user_state) do
    partial = set_user_state(partial, user_state)
    parse(partial, data)
  end

  @doc """
  Terminates the XML document parsing.
  """

  @spec terminate(partial :: t()) ::
          {:ok, state :: term()} | {:error, exception :: Sassone.ParseError.t()}

  def terminate(%__MODULE__{context_fun: context_fun, state: state}) do
    with {:ok, state} <- context_fun.(<<>>, false, state) do
      {:ok, state.user_state}
    end
  end

  @doc """
  Obtain the state set by the user.
  """
  @spec get_state(partial :: t()) :: state :: term()
  def get_state(%__MODULE__{state: %{user_state: user_state}}), do: user_state

  @spec set_user_state(partial :: t(), user_state :: term()) :: partial :: t()
  defp set_user_state(%__MODULE__{state: state} = partial, user_state),
    do: %{partial | state: %{state | user_state: user_state}}
end
