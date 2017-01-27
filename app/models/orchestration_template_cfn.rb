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
    (raw_parameters || {}).collect do |key, val|
      OrchestrationTemplate::OrchestrationParameter.new(
        :name          => key,
        :label         => key.titleize,
        :data_type     => val['Type'],
        :default_value => val['Default'],
        :required      => true,
        :description   => val['Description'],
        :hidden        => val['NoEcho'].nil? ? false : val['NoEcho'].downcase == 'true'
      ).tap do |parameter|
        add_allowed_values(parameter, val)
        add_pattern(parameter, val)
        add_length_constraint(parameter, val)
        add_value_constraint(parameter, val)
        apply_constraint_description(parameter, val)
      end
    end
  end

  def deployment_options(manager_class = nil)
    if manager_class.nil? || manager_class.to_s == 'ManageIQ::Providers::Amazon::CloudManager'
      super + aws_deployment_options
    else
      super + openstack_deployment_options
    end
  end

  def self.register_eligible_manager(cloud_manager_class)
    eligible_manager_types << cloud_manager_class
  end

  def self.eligible_manager_types
    @eligible_manager_types ||= [ManageIQ::Providers::Openstack::CloudManager]
  end

  # return the parsing error message if not valid JSON; otherwise nil
  def validate_format
    JSON.parse(content) && nil if content
  rescue JSON::ParserError => err
    err.message
  end

  private

  def aws_deployment_options
    [onfailure_opt(true),
     timeout_opt,
     notifications_opt,
     capabilities_opt,
     resource_types_opt,
     role_opt,
     tags_opt,
     policy_opt]
  end

  def openstack_deployment_options
    [onfailure_opt(false), timeout_opt]
  end

  def onfailure_opt(can_delete)
    choices = {'ROLLBACK' => 'Rollback', 'DO_NOTHING' => 'Do nothing'}
    choices['DELETE'] = 'Delete stack' if can_delete

    OrchestrationTemplate::OrchestrationParameter.new(
      :name        => "stack_onfailure",
      :label       => "On Failure",
      :data_type   => "string",
      :description => "Select what to do if stack creation failed",
      :constraints => [OrchestrationTemplate::OrchestrationParameterAllowed.new(:allowed_values => choices)]
    )
  end

  def timeout_opt
    OrchestrationTemplate::OrchestrationParameter.new(
      :name        => "stack_timeout",
      :label       => "Timeout(minutes, optional)",
      :data_type   => "integer",
      :description => "Abort the creation if it does not complete in a proper time window"
    )
  end

  def notifications_opt
    OrchestrationTemplate::OrchestrationParameter.new(
      :name        => "stack_notifications",
      :label       => "Notification ARNs",
      :data_type   => "text",
      :description => "Notification SNS topic ARNs, one ARN per line"
    )
  end

  def capabilities_opt
    choices = {'' => '<default>', 'CAPABILITY_IAM' => 'CAPABILITY_IAM', 'CAPABILITY_NAMED_IAM' => 'CAPABILITY_NAMED_IAM'}
    OrchestrationTemplate::OrchestrationParameter.new(
      :name        => "stack_capabilities",
      :label       => "Capabilities",
      :data_type   => "string",
      :description => "Choose one or both capabilities",
      :constraints => [OrchestrationTemplate::OrchestrationParameterAllowed.new(:allowed_values => choices)]
    )
  end

  def resource_types_opt
    OrchestrationTemplate::OrchestrationParameter.new(
      :name        => "stack_resource_types",
      :label       => "Permmited resource types",
      :data_type   => "text",
      :description => "Grand permissions to selected types, one type per line"
    )
  end

  def role_opt
    OrchestrationTemplate::OrchestrationParameter.new(
      :name        => "stack_role",
      :label       => "Role ARN",
      :data_type   => "string",
      :description => "ARN of an IAM role used to create the stack"
    )
  end

  def tags_opt
    OrchestrationTemplate::OrchestrationParameter.new(
      :name        => "stack_tags",
      :label       => "AWS Tags",
      :data_type   => "text",
      :description => "Key-value pairs with format key1=>val1, one pair per line"
    )
  end

  def policy_opt
    OrchestrationTemplate::OrchestrationParameter.new(
      :name        => "stack_policy",
      :label       => "Policy",
      :data_type   => "text",
      :description => "URL of an policy file or the actual content of the policy"
    )
  end

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
