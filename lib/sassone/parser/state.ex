defmodule Sassone.Parser.State do
  @moduledoc false

  alias Sassone.{Handler, XML}

  @type t :: %__MODULE__{
          cdata_as_characters: boolean(),
          character_data_max_length: pos_integer() | :infinity,
          expand_entity: :keep | :never | :skip | {module(), atom(), [term()]},
          handler: Handler.t(),
          prolog: Keyword.t(),
          stack: [{XML.namespace(), XML.element()}],
          user_state: Handler.state()
        }
  @enforce_keys [
    :handler,
    :user_state,
    :prolog,
    :expand_entity,
    :character_data_max_length,
    :cdata_as_characters
  ]

  defstruct cdata_as_characters: true,
            character_data_max_length: :infinity,
            expand_entity: :keep,
            handler: nil,
            prolog: nil,
            stack: [],
            user_state: nil
end
