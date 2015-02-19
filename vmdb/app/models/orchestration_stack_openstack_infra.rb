class OrchestrationStackOpenstackInfra < OrchestrationStack
  def raw_update_stack(options)
    planning_data = {}
    ext_management_system.with_provider_connection(:service => "Planning") do |connection|
      # Send new parameters to Tuskar and get updated plan
      connection.plans.find_by_name(name).patch(options)
      plan = connection.plans.find_by_name(name)

      # Get all parameters needed for heat stack-update from Tuskar
      planning_data = {
        :stack_name       => name,
        :template         => plan.master_template,
        :environment      => plan.environment,
        :files            => plan.provider_resource_templates,
        :timeout_mins     => 60,
        :disable_rollback => true
      }
    end

    ext_management_system.with_provider_connection(:service => "Orchestration") do |connection|
      # Update stack with updated planning data
      stack = connection.stacks.get(name, ems_ref)
      # Update stack with updated planning data
      connection.update_stack(stack, planning_data)
    end
  end
end
