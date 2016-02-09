# unfortunately there seems no other way to set the options because .call is called directly from sprockets
Sprockets::ES6.instance.instance_variable_set(:@options, {:optional => %w(
 es7.functionBind
 es7.decorators
 es7.objectRestSpread
)})
