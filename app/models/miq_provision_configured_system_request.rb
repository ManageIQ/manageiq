class MiqProvisionConfiguredSystemRequest < MiqRequest
  TASK_DESCRIPTION  = 'Configured System Provisioning'
  SOURCE_CLASS_NAME = 'ConfiguredSystem'

  validates_inclusion_of :request_state, :in => %w(pending finished) + ACTIVE_STATES, :message => "should be pending, #{ACTIVE_STATES.join(", ")} or finished"
  validate               :must_have_user

  def host_name
    options[:src_configured_system_ids].length == 1 ? src_configured_systems.pluck(:hostname).first : "Multiple Hosts"
  end

  def src_configured_systems
    ConfiguredSystem.where(:id => options[:src_configured_system_ids])
  end

  def requested_task_idx
    options[:src_configured_system_ids]
  end

  def my_zone
    src_configured_systems.first.my_zone
  end

  def my_role(_action = nil)
    'ems_operations'
  end

  def my_queue_name
    src_configured_systems.first.nil? ? super : src_configured_systems.first&.queue_name_for_ems_operations
  end

  def self.request_task_class_from(_attribs)
    ManageIQ::Providers::Foreman::ConfigurationManager::ProvisionTask
  end

  def self.new_request_task(attribs)
    request_task_class_from(attribs).new(attribs)
  end

  def originating_controller
    "configured_system"
  end

  def event_name(mode)
    "configured_system_provision_request_#{mode}"
  end

  private

  def default_description
    _("%{table} install on [%{name}]") % {:table => ui_lookup(:ui_title => 'foreman'), :name => host_name}
  end
end
