Sprockets::ES6.configure do |babel5|
  babel5.optional = %w(
    es7.functionBind
    es7.decorators
    es7.objectRestSpread
  )
end
