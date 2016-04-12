class MiqExpression::Field
  FIELD_REGEX = /
(?<model_name>([[:upper:]][[:alnum:]]*(::)?)+)
\.?(?<associations>[a-z_\.]+)*
-(?<column>[a-z]+(_[a-z]+)*)
/x

  ParseError = Class.new(StandardError)

  def self.parse(field)
    match = FIELD_REGEX.match(field) or raise ParseError, field
    model = match[:model_name].constantize
    klass = model
    associations = match[:associations].to_s.split(".").collect do |association|
      klass = klass.reflection_with_virtual(association).klass
    end
    new(model, associations, match[:column])
  end

  attr_reader :model, :associations, :column
  delegate :eq, :not_eq, :lteq, :gteq, :lt, :gt, :to => :arel_attribute

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

  def target
    if associations.none?
      model
    else
      associations.last
    end
  end

  private

  def arel_attribute
    target.arel_attribute(column)
  end

  def column_type
    target.type_for_attribute(column).type
  end
end
