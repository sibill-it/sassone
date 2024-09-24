defmodule Sassone.TestSchemas do
  @moduledoc false

  defmodule Person do
    @moduledoc false

    @derive {
      Sassone.Builder,
      element_case: :snake,
      root_element: "person",
      fields: [
        bio: [type: :content],
        gender: [type: :attribute],
        name: [type: :element],
        surname: [type: :element]
      ]
    }
    defstruct [:bio, :gender, :name, :surname]
  end
end
