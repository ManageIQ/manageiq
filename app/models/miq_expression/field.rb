class MiqExpression::Field
  FIELD_REGEX = /
(?<model_name>([[:upper:]][[:alnum:]]*(::)?)+)
\.?(?<association>[a-z_]+)?
-(?<column>[a-z]+(_[a-z]+)*)
/x

  ParseError = Class.new(StandardError)

  def self.parse(field)
    match = FIELD_REGEX.match(field) or raise ParseError, field
    new(match[:model_name].constantize, match[:association], match[:column])
  end

  attr_reader :model, :association, :column
  delegate :table_name, :to => :target

  def initialize(model, association, column)
    @model = model
    @association = association
    @column = column
  end

  def date?
    column_type == :date
  end

  def datetime?
    column_type == :datetime
  end

  private

  def target
    if association
      association.classify.constantize
    else
      model
    end
  end

  def column_type
    target.type_for_attribute(column).type
  end
end
