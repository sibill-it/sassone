defmodule Sassone.TestSchemas do
  @moduledoc false

  defmodule Person do
    @derive {
      Sassone.Builder,
      element_case: :snake,
      root_element: "person",
      fields: [
        gender: [type: :attribute],
        name: [type: :element],
        surname: [type: :element]
      ]
    }
    defstruct [:bio, :gender, :name, :surname]
  end
end
