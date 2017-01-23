class ServiceTemplateOrchestration < ServiceTemplate
  include ServiceOrchestrationMixin

  before_save :remove_invalid_resource

  def self.create_catalog_item(options, _auth_user = nil)
    transaction do
      create(options.except(:config_info)).tap do |service_template|
        config_info = options[:config_info]

        service_template.orchestration_template = if config_info[:template_id]
                                                    OrchestrationTemplate.find(config_info[:template_id])
                                                  end

        service_template.orchestration_manager = if config_info[:manager_id]
                                                   ExtManagementSystem.find(config_info[:manager_id])
                                                 end

        service_template.create_resource_actions(config_info)
      end
    end
  end

  def remove_invalid_resource
    # remove the resource from both memory and table
    service_resources.to_a.delete_if { |r| r.destroy unless r.resource }
  end

  def create_subtasks(_parent_service_task, _parent_service)
    # no sub task is needed for this service
    []
  end

  def self.default_provisioning_entry_point(_service_type)
    '/Cloud/Orchestration/Provisioning/StateMachines/Provision/CatalogItemInitialization'
  end

  def self.default_reconfiguration_entry_point
    '/Cloud/Orchestration/Reconfiguration/StateMachines/Reconfigure/default'
  end

  def my_zone
    orchestration_manager.try(:my_zone) || MiqServer.my_zone
  end
end
