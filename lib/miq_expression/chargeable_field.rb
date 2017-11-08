class MiqExpression::ChargeableField < MiqExpression::Target
  STORAGE_ALLOCATED_PREFIX = 'storage_allocated_'.freeze

  REGEX = /
(?<model_name>([[:alnum:]]*(::)?){4})
-(?<column>#{STORAGE_ALLOCATED_PREFIX}[a-z]+[_\-[:alnum:]]+)
/x

  def self.parse(field)
    return unless field.include?(STORAGE_ALLOCATED_PREFIX)

    parsed_params = parse_params(field) || return
    return unless parsed_params[:model_name]
    new(parsed_params[:model_name], nil, parsed_params[:column])
  end
end
