(
  (call
    function: (identifier) @call.name
    arguments: (argument_list) @call.args
  ) @call.node
)

(
  (call
    function: (attribute
      attribute: (identifier) @call.name)
    arguments: (argument_list) @call.args
  ) @call.node
)
