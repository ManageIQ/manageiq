class MiqProvisionConfiguredSystemRequest < MiqRequest
  TASK_DESCRIPTION  = 'Configured System Provisioning'
  SOURCE_CLASS_NAME = 'ConfiguredSystem'
  REQUEST_TYPES     = %w(provision_via_foreman)

  validates_inclusion_of :request_type,  :in => REQUEST_TYPES,                        :message => "should be #{REQUEST_TYPES.join(", ")}"
  validates_inclusion_of :request_state, :in => %w(pending finished) + ACTIVE_STATES, :message => "should be pending, #{ACTIVE_STATES.join(", ")} or finished"
  validate               :must_have_user

  default_value_for :request_type, REQUEST_TYPES.first
  default_value_for :message,      "#{TASK_DESCRIPTION} - Request Created"
  default_value_for(:requester)    { |r| r.get_user }

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

  def my_role
    'ems_operations'
  end

  def self.request_task_class_from(_attribs)
    MiqProvisionTaskConfiguredSystemForeman
  end

  def self.new_request_task(attribs)
    request_task_class_from(attribs).new(attribs)
  end

  def originating_controller
    "configured_system"
  end

  private

  def default_description
    "#{ui_lookup(:ui_title => 'foreman')} install on [#{host_name}]"
  end
end
