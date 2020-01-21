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

  def self.parse(field)
    parsed_params = parse_params(field) || return
    return unless parsed_params[:model_name]
    new(parsed_params[:model_name], parsed_params[:associations], parsed_params[:column] ||
        parsed_params[:virtual_custom_column])
  end

  def self.is_field?(field)
    parse(field)&.valid? || false
  end

  def to_s
    "#{[model, *associations].join(".")}-#{column}"
  end

  def valid?
    (target < ApplicationRecord) &&
      (target.column_names.include?(column) || virtual_attribute? || custom_attribute_column?)
  end

  def attribute_supported_by_sql?
    !custom_attribute_column? && target.attribute_supported_by_sql?(column) && reflection_supported_by_sql?
  end

  def custom_attribute_column?
    column.include?(CustomAttributeMixin::CUSTOM_ATTRIBUTES_PREFIX)
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

  def report_column
    (associations + [column]).join('.')
  end

  # this should only be accessed in MiqExpression
  # please avoid using it
  def arel_table
    if associations.none?
      model.arel_table
    else
      # if we are pointing to a table that already in the query, need to alias it
      # seems we should be able to ask AR to do this for us...
      ref = reflections.last
      if ref.klass.table_name == model.table_name
        ref.klass.arel_table.alias(ref.alias_candidate(model.table_name))
      else
        ref.klass.arel_table
      end
    end
  end

  # this should only be accessed in MiqExpression
  # please avoid using it
  def arel_attribute
    target.arel_attribute(column, arel_table) if target
  end

  private

  def custom_attribute_column_name
    column.gsub(CustomAttributeMixin::CUSTOM_ATTRIBUTES_PREFIX, "")
  end
end
