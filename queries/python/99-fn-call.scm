(
  (call
    function: (identifier) @call.name
    arguments: (arguments) @call.args
  ) @call.node
)

(
  (call
    function: (attribute
      attribute: (identifier) @call.name)
    arguments: (arguments) @call.args
  ) @call.node
)
