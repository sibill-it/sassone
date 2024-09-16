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
end
