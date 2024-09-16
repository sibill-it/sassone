defmodule Sassone.Emitter do
  @moduledoc false

  alias Sassone.{Parser, State}

  def emit(event_type, data, state, on_halt) do
    case emit(event_type, data, state) do
      {:ok, state} -> {:cont, state}
      {:stop, state} -> {:ok, state}
      {:halt, state} -> {:halt, state, on_halt}
      {:error, exception} -> {:error, exception}
    end
  end

  defp emit(event_type, data, %State{} = state) do
    case state.handler.handle_event(event_type, data, state.user_state) do
      {:cont, handler, user_state} ->
        {:ok, %{state | handler: handler, state: user_state}}

      {result, user_state} when result in [:ok, :stop, :halt] ->
        {result, %{state | user_state: user_state}}

      other ->
        Parser.Utils.bad_return_error({event_type, other})
    end
  end

  @compile {:inline, [convert_entity_reference: 2]}

  def convert_entity_reference(reference_name, %{expand_entity: :never}),
    do: [?&, reference_name, ?;]

  def convert_entity_reference("amp", _state), do: [?&]
  def convert_entity_reference("lt", _state), do: [?<]
  def convert_entity_reference("gt", _state), do: [?>]
  def convert_entity_reference("apos", _state), do: [?']
  def convert_entity_reference("quot", _state), do: [?"]

  def convert_entity_reference(reference_name, state) do
    case state.expand_entity do
      :keep -> [?&, reference_name, ?;]
      :skip -> []
      {mod, fun, args} -> apply(mod, fun, [reference_name | args])
    end
  end
end
