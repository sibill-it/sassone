defprotocol Sassone.Encoder do
  @moduledoc """
  Protocol for encoding values in XML content.

  Default implementations are provided for built-in data types.
  """

  @type t :: term()

  @doc "Encodes a value to a string for representation in XML."
  @spec encode(t()) :: String.t() | [String.t()]
  def encode(t)
end

defimpl Sassone.Encoder, for: BitString do
  def encode(binary), do: binary
end

defimpl Sassone.Encoder, for: Atom do
  def encode(nil), do: ""
  def encode(value), do: Atom.to_string(value)
end

defimpl Sassone.Encoder, for: Integer do
  def encode(value), do: Integer.to_string(value)
end

defimpl Sassone.Encoder, for: Float do
  def encode(value), do: Float.to_string(value)
end

defimpl Sassone.Encoder, for: NaiveDateTime do
  def encode(value), do: NaiveDateTime.to_iso8601(value)
end

defimpl Sassone.Encoder, for: DateTime do
  def encode(value), do: DateTime.to_iso8601(value)
end

defimpl Sassone.Encoder, for: Date do
  def encode(value), do: Date.to_iso8601(value)
end

defimpl Sassone.Encoder, for: Time do
  def encode(value), do: Time.to_iso8601(value)
end

defimpl Sassone.Encoder, for: List do
  def encode(value), do: Enum.map(value, &Sassone.Encoder.encode/1)
end
