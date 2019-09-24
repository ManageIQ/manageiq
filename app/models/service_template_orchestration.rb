class ServiceTemplateOrchestration < ServiceTemplate
  include ServiceOrchestrationMixin

  before_save :remove_invalid_resource

  def self.create_catalog_item(options, _auth_user = nil)
    transaction do
      create_from_options(options).tap do |service_template|
        config_info = validate_config_info(options)

        service_template.orchestration_template = if config_info[:template_id]
                                                    OrchestrationTemplate.find(config_info[:template_id])
                                                  else
                                                    config_info[:template]
                                                  end
        service_template.orchestration_manager = if config_info[:manager_id]
                                                   ExtManagementSystem.find(config_info[:manager_id])
                                                 else
                                                   config_info[:manager]
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

  def self.validate_config_info(options)
    config_info = options[:config_info]
    unless (config_info[:template_id] && config_info[:manager_id]) || (config_info[:template] && config_info[:manager])
      raise _('Must provide both template_id and manager_id or manager and template')
    end
    config_info
  end

  private

  def update_service_resources(config_info, _auth_user = nil)
    if config_info[:template_id] && config_info[:template_id] != orchestration_template.try(:id)
      self.orchestration_template = OrchestrationTemplate.find(config_info[:template_id])
    elsif config_info[:template] && config_info[:template] != orchestration_template
      self.orchestration_template = config_info[:template]
    end

    if config_info[:manager_id] && config_info[:manager_id] != orchestration_manager.try(:id)
      self.orchestration_manager = ExtManagementSystem.find(config_info[:manager_id])
    elsif config_info[:manager] && config_info[:manager] != orchestration_manager
      self.orchestration_manager = config_info[:manager]
    end
  end

  def validate_update_config_info(options)
    super
    return unless options.key?(:config_info)
    self.class.validate_config_info(options)
  end

  def construct_config_info
    config_info = {}

    config_info[:template_id] = orchestration_template.id if orchestration_template
    config_info[:manager_id] = orchestration_manager.id if orchestration_manager

    config_info.merge!(resource_actions_info)
  end
end
