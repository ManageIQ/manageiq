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
    return false unless field.kind_of?(String)
    match = REGEX.match(field)
    return false unless match
    model =
      begin
        match[:model_name].safe_constantize
      rescue LoadError
        nil
      end
    return false unless model
    !!(model < ApplicationRecord)
  end

  def to_s
    "#{[model, *associations].join(".")}-#{column}"
  end

  def valid?
    target.column_names.include?(column) || virtual_attribute? || custom_attribute_column?
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

  private

  def custom_attribute_column_name
    column.gsub(CustomAttributeMixin::CUSTOM_ATTRIBUTES_PREFIX, "")
  end
end
