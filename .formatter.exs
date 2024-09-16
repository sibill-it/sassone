# Used by "mix format"
[
  import_deps: [:stream_data],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: [defhalt: 1, emit_event: 2]
]
