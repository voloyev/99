(import_statement
  module_name: (dotted_name) @import.name) @import.decl

(import_from_statement
  module_name: (dotted_name) @import.name
  names: (import_list (imported_name (identifier) @import.name)) @import.decl)

(import_from_statement
  module_name: (dotted_name) @import.name
  names: (import_list (imported_binding (identifier) @import.name)) @import.decl)
