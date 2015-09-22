class ManageIQ::Providers::Openstack::InfraManager::OrchestrationStack < ::OrchestrationStack
  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::InfraManager"

  def raw_update_stack(parameters)
    ext_management_system.with_provider_connection(:service => "Orchestration") do |connection|
      stack    = connection.stacks.get(name, ems_ref)
      template = connection.get_stack_template(stack).body

      connection.patch_stack(stack, 'template' => template, 'parameters' => parameters)
    end
  end

  def update_ready?
    # Update is possible only when in complete or failed state, otherwise API returns exception
    raw_status.first.end_with?("_COMPLETE", "_FAILED")
  end
end
