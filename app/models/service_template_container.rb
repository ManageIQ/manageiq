class ServiceTemplateContainer < ServiceTemplate
  include ServiceContainerMixin

  before_save :remove_invalid_resource

  def remove_invalid_resource
    # remove the resource from both memory and table
    service_resources.to_a.delete_if { |r| r.destroy unless r.resource(true) }
  end

  def create_subtasks(_parent_service_task, _parent_service)
    # no sub task is needed for this service
    []
  end

  def self.default_provisioning_entry_point(_service_type)
    '/Container/Service/Provisioning/StateMachines/Provision/CatalogItemInitialization'
  end

  def self.default_reconfiguration_entry_point
    nil
  end

  def self.default_retirement_entry_point
    nil
  end
end
