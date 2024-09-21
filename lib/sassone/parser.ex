defmodule Sassone.Parser do
  @moduledoc false

  defmodule Binary do
    @moduledoc false

    use Sassone.Parser.Builder, streaming?: false
  end

  defmodule Stream do
    @moduledoc false

    use Sassone.Parser.Builder, streaming?: true
  end

  alias Sassone.Parser.State

  @compile {:inline, [convert_entity_reference: 2]}

  def convert_entity_reference(reference_name, %{expand_entity: :never}),
    do: [?&, reference_name, ?;]

  def convert_entity_reference("amp", _state), do: [?&]
  def convert_entity_reference("lt", _state), do: [?<]
  def convert_entity_reference("gt", _state), do: [?>]
  def convert_entity_reference("apos", _state), do: [?']
  def convert_entity_reference("quot", _state), do: [?"]

  def convert_entity_reference(reference_name, %State{} = state) do
    case state.expand_entity do
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
