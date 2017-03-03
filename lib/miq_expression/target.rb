class MiqExpression::Target
  def initialize(model, associations, column)
    @model = model
    @associations = associations
    @column = column
  end
end