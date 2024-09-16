# Changelog

## v1.0.0 - 2024-09-16

* Add support for `{:cont, handler, state}` as `Saxy.Handler` callbacks return value.
  This allows for splitting the parser in multiple handlers.
* Return namespace separately from element name in `Saxy.Handler` callbacks.
  This allows pattern matching on element names, which is not possibile if the namespace is
  prefixed to it, since you cannot pattern match on a variable length string prefix.
