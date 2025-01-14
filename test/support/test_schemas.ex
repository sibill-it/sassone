defmodule Sassone.TestSchemas do
  @moduledoc false

  defmodule Person do
    @moduledoc false

    @derive {
      Sassone.Builder,
      element_case: :snake,
      root_element: "person",
      fields: [
        gender: [type: :attribute],
        name: [type: :element],
        surname: [type: :element],
        bio: [type: :content]
      ]
    }
    defstruct [:bio, :gender, :name, :surname]
  end

  defmodule Product do
    @moduledoc false

    @derive {
      Sassone.Builder,
      element_case: :snake,
      root_element: "product",
      fields: [
        uuid: [type: :attribute],
        name: [type: :element],
        description: [type: :content]
      ]
    }
    defstruct [:uuid, :name, :description]
  end

  defmodule Line do
    @moduledoc false

    @derive {
      Sassone.Builder,
      element_case: :snake,
      fields: [
        product: [type: :element, struct: Product],
        quantity: [type: :element],
        sorting: [type: :attribute]
      ]
    }
    defstruct [:product, :quantity, :sorting]
  end

  defmodule Order do
    @moduledoc false

    @derive {
      Sassone.Builder,
      element_case: :snake,
      root_element: "order",
      fields: [
        id: [type: :attribute],
        lines: [many: true, struct: Line, name: "line"],
        status: [type: :element],
        ref: [type: :element]
      ]
    }
    defstruct [:id, :lines, :status, :ref]
  end
end
