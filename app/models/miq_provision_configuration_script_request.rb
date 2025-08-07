class MiqProvisionConfigurationScriptRequest < MiqRequest
  TASK_DESCRIPTION  = N_('Configuration Script Provisioning')
  SOURCE_CLASS_NAME = 'ConfigurationScript'

  validates_inclusion_of :request_state, :in => %w[pending finished] + ACTIVE_STATES, :message => "should be pending, #{ACTIVE_STATES.join(", ")} or finished"
  validate               :must_have_user

  def host_name
    options[:src_configured_system_ids].length == 1 ? src_configured_systems.pluck(:hostname).first : "Multiple Hosts"
  end

  def src_configuration_scripts
    ConfigurationScript.where(:id => options[:src_configuration_script_ids])
  end

  def requested_task_idx
    options[:src_configuration_script_ids]
  end

  def my_zone
    src_configuration_scripts.first.my_zone
  end

  def my_role(_action = nil)
    'ems_operations'
  end

  def my_queue_name
    src_configuration_scripts.first.nil? ? super : src_configuration_scripts.first&.queue_name_for_ems_operations
  end

  def self.request_task_class
    ManageIQ::Providers::TerraformEnterprise::AutomationManager::Provision
  end

  def self.request_task_class_from(_attribs)
    # TODO
    ManageIQ::Providers::TerraformEnterprise::AutomationManager::Provision
  end

  def self.new_request_task(attribs)
    request_task_class_from(attribs).new(attribs)
  end

  def originating_controller
    "configuration_scripts"
  end

  def event_name(mode)
    "configuration_script_provision_request_#{mode}"
  end
end
