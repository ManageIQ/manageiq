class ServiceTemplateAnsibleTower < ServiceTemplate
  include ServiceConfigurationMixin

  before_update :remove_invalid_resource

  alias job_template configuration_script
  alias job_template= configuration_script=

  def self.create_catalog_item(options, _auth_user = nil)
    transaction do
      create_from_options(options).tap do |service_template|
        config_info = validate_config_info(options)

        service_template.job_template = if config_info[:configuration_script_id]
                                          ConfigurationScript.find(config_info[:configuration_script_id])
                                        else
                                          config_info[:configuration]
                                        end

        service_template.create_resource_actions(config_info)
      end
    end
  end

  def remove_invalid_resource
    # remove the resource from both memory and table
    service_resources.to_a.delete_if do |r|
      r.reload if r.persisted?
      r.destroy if r.resource.blank?
    end
  end

  def create_subtasks(_parent_service_task, _parent_service)
    # no sub task is needed for this service
    []
  end

  def self.default_provisioning_entry_point(_service_type)
    '/AutomationManagement/AnsibleTower/Service/Provisioning/StateMachines/Provision/CatalogItemInitialization'
  end

  def self.default_reconfiguration_entry_point
    nil
  end

  def self.default_retirement_entry_point
    nil
  end

  def self.validate_config_info(options)
    config_info = options[:config_info]
    unless config_info[:configuration_script_id] || config_info[:configuration]
      raise _('Must provide configuration_script_id or configuration')
    end
    config_info
  end

  def my_zone
    job_template.manager.try(:my_zone)
  end

  private

  def update_service_resources(config_info, _auth_user = nil)
    if config_info[:configuration_script_id] && config_info[:configuration_script_id] != job_template.try(:id)
      service_resources.find_by(:resource_type => 'ConfigurationScriptBase').destroy
      self.job_template = ConfigurationScriptBase.find(config_info[:configuration_script_id])
    elsif config_info[:configuration] && config_info[:configuration] != job_template.try(:id)
      service_resources.find_by(:resource_type => 'ConfigurationScriptBase').destroy
      self.job_template = config_info[:configuration]
    end
  end

  def validate_update_config_info(options)
    super
    return unless options.key?(:config_info)
    self.class.validate_config_info(options)
  end

  def construct_config_info
    config_info = {}
    config_info[:configuration_script_id] = job_template.id if job_template
    config_info.merge!(resource_actions_info)
  end
end
