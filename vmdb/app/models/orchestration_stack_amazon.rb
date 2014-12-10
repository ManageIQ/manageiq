class OrchestrationStackAmazon < OrchestrationStack
  def raw_update_stack(options)
    ext_management_system.with_provider_connection(:service => "CloudFormation") do |connection|
      connection.stacks[name].update(options)
    end
  end

  def raw_delete_stack
    ext_management_system.with_provider_connection(:service => "CloudFormation") do |connection|
      connection.stacks[name].delete
    end
  end
end
