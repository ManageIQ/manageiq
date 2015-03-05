class OrchestrationTemplateCfn < OrchestrationTemplate
  def parameter_groups
    # CFN format does not have the concept of parameter group
    # Place all parameters in one group
    [OrchestrationTemplate::OrchestrationParameterGroup.new(
      :label      => "Parameters",
      :parameters => parameters
    )]
  end

  def parameters
    raw_parameters = JSON.load(content)["Parameters"]
    raw_parameters.collect do |key, val|
      parameter = OrchestrationTemplate::OrchestrationParameter.new(
        :name          => key,
        :label         => key.titleize,
        :data_type     => val['Type'],
        :default_value => val['Default'],
        :description   => val['Description'],
        :hidden        => val['NoEcho'].nil? ? false : val['NoEcho'].downcase == 'true'
      )

      add_allowed_values(parameter, val)
      add_pattern(parameter, val)
      add_length_constraint(parameter, val)
      add_value_constraint(parameter, val)
      apply_constraint_description(parameter, val)

      parameter
    end
  end

  def self.eligible_manager_types
    [EmsAmazon, EmsOpenstack]
  end

  # return the parsing error message if not valid JSON; otherwise nil
  def validate_format
    JSON.parse(content) && nil if content
  rescue JSON::ParserError => err
    err.message
  end

  private

  def add_allowed_values(parameter, val)
    return unless val.key? 'AllowedValues'

    constraint = OrchestrationTemplate::OrchestrationParameterAllowed.new(:allowed_values => val['AllowedValues'])
    parameter.constraints << constraint
  end

  def add_pattern(parameter, val)
    return unless val.key? 'AllowedPattern'

    constraint = OrchestrationTemplate::OrchestrationParameterPattern.new(:pattern => val['AllowedPattern'])
    parameter.constraints << constraint
  end

  def add_length_constraint(parameter, val)
    return unless val.key?('MinLength') || val.key?('MaxLength')

    constraint = OrchestrationTemplate::OrchestrationParameterLength.new
    constraint.min_length = val['MinLength'].to_i if val['MinLength']
    constraint.max_length = val['MaxLength'].to_i if val['MaxLength']
    parameter.constraints << constraint
  end

  def add_value_constraint(parameter, val)
    return unless val.key?('MinValue') || val.key?('MaxValue')

    constraint = OrchestrationTemplate::OrchestrationParameterRange.new
    constraint.min_value = to_number(val['MinValue']) if val['MinValue']
    constraint.max_value = to_number(val['MaxValue']) if val['MaxValue']
    parameter.constraints << constraint
  end

  def to_number(str)
    str.integer? ? str.to_i : str.to_f
  end

  def apply_constraint_description(parameter, val)
    return if (desc = val['ConstraintDescription']).nil?

    parameter.constraints.each { |c| c.description = desc }
  end
end
