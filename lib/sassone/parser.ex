defmodule Sassone.Parser do
  @moduledoc false

  alias Sassone.Parser.Generator

  defmodule Binary do
    @moduledoc false

    use Generator, streaming?: false
  end

  defmodule Stream do
    @moduledoc false

    use Generator, streaming?: true
  end

  @compile {:inline, [convert_entity_reference: 2]}

  def convert_entity_reference(reference_name, :never),
    do: [?&, reference_name, ?;]

  def convert_entity_reference("amp", _expand_entity), do: [?&]
  def convert_entity_reference("lt", _expand_entity), do: [?<]
  def convert_entity_reference("gt", _expand_entity), do: [?>]
  def convert_entity_reference("apos", _expand_entity), do: [?']
  def convert_entity_reference("quot", _expand_entity), do: [?"]

  def convert_entity_reference(reference_name, expand_entity) do
    case expand_entity do
      :keep -> [?&, reference_name, ?;]
      :skip -> []
      {mod, fun, args} -> apply(mod, fun, [reference_name | args])
    end
  end

  def compute_char_len(char) when char <= 0x7F, do: 1
  def compute_char_len(char) when char <= 0x7FF, do: 2
  def compute_char_len(char) when char <= 0xFFFF, do: 3
  def compute_char_len(_char), do: 4

  def valid_pi_name?(<<l::integer, m::integer, x::integer>>)
      when x in [?X, ?x] or m in [?M, ?m] or l in [?L, ?l],
      do: false

  def valid_pi_name?(<<_::bits>>), do: true

  def valid_encoding?(encoding), do: String.upcase(encoding, :ascii) == "UTF-8"
end
