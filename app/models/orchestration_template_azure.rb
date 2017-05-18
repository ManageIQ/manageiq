class OrchestrationTemplateAzure < OrchestrationTemplate
  def parameter_groups
    # Azure format does not have the concept of parameter group
    # Place all parameters in one group
    [OrchestrationTemplate::OrchestrationParameterGroup.new(
      :label      => "Parameters",
      :parameters => parameters
    )]
  end

  def parameters
    raw_parameters = JSON.load(content)["parameters"]
    (raw_parameters || {}).collect do |key, val|
      parameter = OrchestrationTemplate::OrchestrationParameter.new(
        :name          => key,
        :label         => key.titleize,
        :data_type     => val['type'],
        :default_value => val['defaultValue'],
        :hidden        => val['type'] == 'securestring',
        :required      => true
      )

      add_metadata(parameter, val['metadata'])
      add_allowed_values(parameter, val['allowedValues'])

      parameter
    end
  end

  def deployment_options(_manager_class = nil)
    super << resource_group_opt << new_resource_group_opt << mode_opt
  end

  def self.eligible_manager_types
    [ManageIQ::Providers::Azure::CloudManager]
  end

  # return the parsing error message if not valid JSON; otherwise nil
  def validate_format
    JSON.parse(content) && nil if content
  rescue JSON::ParserError => err
    err.message
  end

  private

  def mode_opt
    description = "Select deployment mode.\n"\
                  "WARNING: Complete mode will delete all resources from "\
                  "the group that are not in the template."
    choices = {'Incremental' => 'Incremental (Default)', 'Complete' => 'Complete (Delete other resources in the group)'}
    OrchestrationTemplate::OrchestrationParameter.new(
      :name        => "deploy_mode",
      :label       => "Mode",
      :data_type   => "string",
      :description => description,
      :constraints => [OrchestrationTemplate::OrchestrationParameterAllowed.new(:allowed_values => choices)]
    )
  end

  def resource_group_opt
    OrchestrationTemplate::OrchestrationParameter.new(
      :name        => "resource_group",
      :label       => "Existing Resource Group",
      :data_type   => "string",
      :description => "Select an existing resource group for deployment",
      :constraints => [
        OrchestrationTemplate::OrchestrationParameterAllowedDynamic.new(
          :fqname => "/Cloud/Orchestration/Operations/Methods/Available_Resource_Groups"
        )
      ]
    )
  end

  def new_resource_group_opt
    OrchestrationTemplate::OrchestrationParameter.new(
      :name        => "new_resource_group",
      :label       => "(or) New Resource Group",
      :data_type   => "string",
      :description => "Create a new resource group upon deployment",
      :constraints => [
        OrchestrationTemplate::OrchestrationParameterPattern.new(:pattern => '^[A-Za-z][A-Za-z0-9\-_]*$')
      ]
    )
  end

  def add_metadata(parameter, metadata)
    return unless metadata
    parameter.description = metadata['description']
  end

  def add_allowed_values(parameter, vals)
    return unless vals

    constraint = OrchestrationTemplate::OrchestrationParameterAllowed.new(:allowed_values => vals)
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
