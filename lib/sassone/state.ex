defmodule Sassone.State do
  @moduledoc false

  @enforce_keys [
    :handler,
    :user_state,
    :prolog,
    :expand_entity,
    :character_data_max_length,
    :cdata_as_characters
  ]

  defstruct cdata_as_characters: nil,
            character_data_max_length: nil,
            expand_entity: nil,
            handler: nil,
            prolog: nil,
            stack: [],
            user_state: nil
end
