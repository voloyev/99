(call
  method: (identifier) @import.name
  (#eq? @import.name "require")) @import.decl

(call
  method: (identifier) @import.name
  (#eq? @import.name "require_relative")) @import.decl
