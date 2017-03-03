class MiqExpression::Target
  ParseError = Class.new(StandardError)

  def self.parse!(field)
    parse(field) || raise(ParseError, field)
  end

  attr_reader :model, :associations, :column

  def initialize(model, associations, column)
    @model = model
    @associations = associations
    @column = column
  end
end