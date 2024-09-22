defmodule Sassone.Prolog do
  @moduledoc "XML Prolog"

  defstruct [
    :version,
    :encoding,
    :standalone
  ]

  @type t() :: %__MODULE__{
          version: String.t(),
          encoding: atom() | String.t(),
          standalone: boolean()
        }

  def from_keyword(prolog) do
    %__MODULE__{
      version: prolog[:version] || "1.0",
      encoding: prolog[:encoding],
      standalone: prolog[:standalone]
    }
  end
end
