defmodule SassoneTest.ParsingCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      use ExUnitProperties

      import SassoneTest.Utils
    end
  end
end
