class MiqExpression::Field < MiqExpression::Target
  REGEX = /
(?<model_name>([[:upper:]][[:alnum:]]*(::)?)+)
(?!.*\b(managed|user_tag)\b)
\.?(?<associations>[a-z][0-9a-z_\.]+)?
-
(?:
  (?<virtual_custom_column>#{CustomAttributeMixin::CUSTOM_ATTRIBUTES_PREFIX}[a-z]+[:_\-.\/[:alnum:]]*)|
  (?<column>[a-z]+(_[[:alnum:]]+)*)
)
/x

  delegate :eq, :not_eq, :lteq, :gteq, :lt, :gt, :between, :to => :arel_attribute

  def self.parse(field)
    parsed_params = parse_params(field) || return
    new(parsed_params[:model_name], parsed_params[:associations], parsed_params[:column] ||
        parsed_params[:virtual_custom_column])
  end

  def self.is_field?(field)
    return false unless field.kind_of?(String)
    match = REGEX.match(field)
    return false unless match
    model = match[:model_name].safe_constantize
    return false unless model
    !!(model < ApplicationRecord)
  end

  def attribute_supported_by_sql?
    !custom_attribute_column? && target.attribute_supported_by_sql?(column)
  end

  def custom_attribute_column?
    column.include?(CustomAttributeMixin::CUSTOM_ATTRIBUTES_PREFIX)
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

  def virtual_attribute?
    target.virtual_attribute?(column)
  end

  def sub_type
    MiqReport::Formats.sub_type(column.to_sym) || column_type
  end

  def arel_attribute
    target.arel_attribute(column)
  end

  def report_column
    (associations + [column]).join('.')
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
end
