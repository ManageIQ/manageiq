class MiqExpression::Field
  FIELD_REGEX = /
(?<model_name>([[:upper:]][[:alnum:]]*(::)?)+)
\.?(?<associations>[a-z_\.]+)*
-
(?:
  (?<virtual_custom_column>#{CustomAttributeMixin::CUSTOM_ATTRIBUTES_PREFIX}[a-z]+[_\-.\/[:alnum:]]*)|
  (?<column>[a-z]+(_[[:alnum:]]+)*)
)
/x

  ParseError = Class.new(StandardError)

  def self.parse(field)
    match = FIELD_REGEX.match(field) or raise ParseError, field
    new(match[:model_name].constantize, match[:associations].to_s.split("."), match[:virtual_custom_column] ||
        match[:column])
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

  def plural?
    return false if reflections.empty?
    [:has_many, :has_and_belongs_to_many].include?(reflections.last.macro)
  end

  def custom_attribute_column?
    column.include?(CustomAttributeMixin::CUSTOM_ATTRIBUTES_PREFIX)
  end

  def reflections
    klass = model
    associations.collect do |association|
      klass.reflection_with_virtual(association).tap do |reflection|
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

  def contains(other)
    raise unless associations.one?
    reflection = reflections.first
    arel = eq(other)
    arel = arel.and(Arel::Nodes::SqlLiteral.new(extract_where_values(reflection.klass, reflection.scope))) if reflection.scope
    model.arel_attribute(:id).in(
      target.arel_table.where(arel).project(target.arel_table[reflection.foreign_key]).distinct
    )
  end

  def column_type
    if custom_attribute_column?
      CustomAttribute.where(:name => custom_attribute_column_name, :resource_type => model.to_s).first.try(:value_type)
    else
      target.type_for_attribute(column).type
    end
  end

  private

  def custom_attribute_column_name
    column.gsub(CustomAttributeMixin::CUSTOM_ATTRIBUTES_PREFIX, "")
  end

  class WhereExtractionVisitor < Arel::Visitors::PostgreSQL
    def visit_Arel_Nodes_SelectStatement(o, collector)
      collector = o.cores.inject(collector) do |c, x|
        visit_Arel_Nodes_SelectCore(x, c)
      end
    end

    def visit_Arel_Nodes_SelectCore(o, collector)
      unless o.wheres.empty?
        len = o.wheres.length - 1
        o.wheres.each_with_index do |x, i|
          collector = visit(x, collector)
          collector << AND unless len == i
        end
      end

      collector
    end
  end

  def extract_where_values(klass, scope)
    relation = ActiveRecord::Relation.new klass, klass.arel_table, klass.predicate_builder
    relation = relation.instance_eval(&scope)

    begin
      # This is basically ActiveRecord::Relation#to_sql, only using our
      # custom visitor instance

      connection = klass.connection
      visitor    = WhereExtractionVisitor.new connection

      arel  = relation.arel
      binds = relation.bound_attributes
      binds = connection.prepare_binds_for_database(binds)
      binds.map! { |value| connection.quote(value) }
      collect = visitor.accept(arel.ast, Arel::Collectors::Bind.new)
      collect.substitute_binds(binds).join
    end
  end

  def arel_attribute
    target.arel_attribute(column)
  end
end
