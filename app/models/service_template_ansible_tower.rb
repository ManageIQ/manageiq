class ServiceTemplateAnsibleTower < ServiceTemplate
  include ServiceConfigurationMixin

  before_save :remove_invalid_resource

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
    service_resources.to_a.delete_if { |r| r.destroy unless r.resource(true) }
  end

  def create_subtasks(_parent_service_task, _parent_service)
    # no sub task is needed for this service
    []
  end

  def self.default_provisioning_entry_point(_service_type)
    '/ConfigurationManagement/AnsibleTower/Service/Provisioning/StateMachines/Provision/provision_from_bundle'
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
  private_class_method :validate_config_info

  private

  def construct_config_info
    config_info = {}
    config_info[:configuration_script_id] = job_template.id if job_template
    config_info.merge!(resource_actions_info)
  end
end
