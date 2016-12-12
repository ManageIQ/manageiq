class ManageIQ::Providers::Amazon::CloudManager::OrchestrationServiceOptionConverter < ::ServiceOrchestration::OptionConverter
  REGEX_TAGS = /([^(=>)\n ]+)[(=>) ]+([^(=>)\n ]+)[ \n]*/
  private_constant :REGEX_TAGS, :REGEX_TAGS

  def stack_create_options
    timeout = @dialog_options['dialog_stack_timeout']
    policy_body, policy_url = parse_policy(@dialog_options['dialog_stack_policy'])

    stack_options = {
      :parameters         => stack_parameters,
      :on_failure         => @dialog_options['dialog_stack_onfailure'],
      :timeout_in_minutes => timeout.blank? ? nil : timeout.to_i,
      :notification_arns  => parse_multiple_lines(@dialog_options['dialog_stack_notifications']),
      :capabilities       => parse_capacities(@dialog_options['dialog_stack_capabilities']),
      :resource_types     => parse_multiple_lines(@dialog_options['dialog_stack_resource_types']),
      :role_arn           => @dialog_options['dialog_stack_role'],
      :stack_policy_body  => policy_body,
      :stack_policy_url   => policy_url,
      :tags               => parse_tags(@dialog_options['dialog_stack_tags'])
    }

    stack_options.select { |_k, v| v.present? }
  end

  private

  def parse_capacities(input)
    return input if input.blank? || input.kind_of?(Array)

    # currently the dropdown cannot be multi-selected, but it will be enabled soon
    [input]
  end

  def parse_multiple_lines(input)
    return if input.blank?

    input.split("\n").collect(&:strip).select(&:present?)
  end

  def parse_tags(input)
    return if input.blank?

    # input example: "tag_key1 => tag_val1\n tag_key2 => tag_val2"
    input.scan(REGEX_TAGS).each_with_object([]) { |tag, arr| arr.push({:key => tag.first, :value => tag.last}) }
  end

  def parse_policy(input)
    return unless input

    begin
      JSON.parse(input)
      policy_body = input
    rescue JSON::ParserError
      policy_url = input
    end
    [policy_body, policy_url]
  end
end
