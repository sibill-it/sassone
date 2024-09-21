defmodule Sassone.Parser.Builder.Lookahead do
  @moduledoc false

  def edge_ngrams(word) do
    {grams, _} =
      word
      |> String.to_charlist()
      |> Enum.flat_map_reduce("", fn char, last_word ->
        last_word = last_word <> <<char>>
        {[last_word], last_word}
      end)

    grams ++ [""]
  end

  defmacro lookahead(data, streaming?, do: rules) do
    streaming? = Macro.expand(streaming?, __CALLER__)

    quote do
      case unquote(data) do
        unquote(build_clauses(rules, streaming?))
      end
    end
  end

  defp build_clauses([], _streaming?), do: []

  defp build_clauses([{:->, _, [clause, code]} | rest], streaming?) do
    build_clause(clause, code, streaming?) ++ build_clauses(rest, streaming?)
  end

  # "binary" <> rest.
  defp build_clause([{:<>, _, [ahead, rest]}], code, _streaming?) do
    quote do
      <<unquote(ahead), unquote(rest)::bits>> -> unquote(code)
    end
  end

  # "in" is exclusively used in streaming.
  defp build_clause([{:when, _, [{:in, _, [token_var, tokens]}, guards]}], code, true) do
    Enum.flat_map(tokens, fn token ->
      quote do
        unquote(token) when unquote(guards) ->
          unquote(token_var) = unquote(token)
          unquote(code)
      end
    end)
  end

  defp build_clause([{:when, _, [{:in, _, _}, _guards]}], _code, _streaming?), do: []

  # char <> rest when is_whitespace(char).
  defp build_clause([{:when, _, [{:<>, _, [ahead, rest]}, guards]}], code, _streaming?) do
    quote do
      <<unquote(ahead), unquote(rest)::bits>> when unquote(guards) ->
        unquote(code)
    end
  end

  defp build_clause([other], code, _streaming?) do
    quote do
      unquote(other) -> unquote(code)
    end
  end
end
