class MiqExpression::Field
  FIELD_REGEX = /
(?<model_name>([[:upper:]][[:alnum:]]*(::)?)+)
\.?(?<associations>[a-z_\.]+)*
-(?<column>[a-z]+(_[a-z]+)*)
/x

  ParseError = Class.new(StandardError)

  def self.parse(field)
    match = FIELD_REGEX.match(field) or raise ParseError, field
    new(match[:model_name].constantize, match[:associations].to_s.split("."), match[:column])
  end

  attr_reader :model, :associations, :column
  delegate :eq, :not_eq, :lteq, :gteq, :lt, :gt, :between, :to => :arel_attribute

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

  def string?
    column_type == :string
  end

  def reflections
    klass = model
    associations.collect do |association|
      klass.reflect_on_association(association).tap do |reflection|
        raise ArgumentError, "One or more associations are invalid: #{associations.join(", ")}" unless reflection
        klass = reflection.klass
      end
    end
  end

  def target
    if associations.none?
      model
    else
      reflections.last.klass
    end
  end

  def matches(other)
    escape = nil
    case_sensitive = true
    arel_attribute.matches(other, escape, case_sensitive)
  end

  def does_not_match(other)
    escape = nil
    case_sensitive = true
    arel_attribute.does_not_match(other, escape, case_sensitive)
  end

  private

  def arel_attribute
    target.arel_attribute(column)
  end

  def column_type
    target.type_for_attribute(column).type
  end
end
