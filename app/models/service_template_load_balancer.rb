class ServiceTemplateLoadBalancer < ServiceTemplate
  include ServiceLoadBalancerMixin

  before_save :remove_invalid_resource

  def remove_invalid_resource
    # remove the resource from both memory and table
    service_resources.to_a.delete_if { |r| r.destroy unless r.resource }
  end

  def create_subtasks(_parent_service_task, _parent_service)
    # no sub task is needed for this service
    []
  end

  def self.default_provisioning_entry_point
    '/Cloud/LoadBalancer/Provisioning/StateMachines/Provision/default'
  end

  def self.default_reconfiguration_entry_point
    '/Cloud/LoadBalancer/Reconfiguration/StateMachines/Reconfigure/default'
  end
end
