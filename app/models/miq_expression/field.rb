class MiqExpression::Field
  FIELD_REGEX = /
(?<model_name>[[:upper:]][[:alnum:]]*)
\.?(?<associations>[a-z_\.]+)*
-(?<column>[a-z]+(_[a-z]+)*)
/x

  def self.parse(field)
    match = FIELD_REGEX.match(field)
    new(match[:model_name].constantize, match[:associations].to_s.split("."), match[:column])
  end

  attr_reader :model, :associations, :column
  delegate :table_name, :to => :target

  def initialize(model, associations, column)
    @model = model
    @associations = associations
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
    if associations.none?
      model
    else
      associations.last.classify.constantize
    end
  end

  def column_type
    target.type_for_attribute(column).type
  end
end
