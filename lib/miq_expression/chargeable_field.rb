class MiqExpression::ChargeableField < MiqExpression::Target
  STORAGE_ALLOCATED_PREFIX = 'storage_allocated_'.freeze
  SPECIAL_CHARACTERS = '_./,;\\-{}()*&^% $#@!+"\''.freeze

  REGEX = /
(?<model_name>([[:alnum:]]*(::)?){4})
-(?<column>#{STORAGE_ALLOCATED_PREFIX}[#{SPECIAL_CHARACTERS}[:alnum:]]+)
/x

  def self.parse(field)
    return unless field.include?(STORAGE_ALLOCATED_PREFIX)

    parsed_params = parse_params(field) || return
    return unless parsed_params[:model_name]
    new(parsed_params[:model_name], nil, parsed_params[:column])
  end

  def storage_allocated_field?
    @column.include?(STORAGE_ALLOCATED_PREFIX)
  end
end
