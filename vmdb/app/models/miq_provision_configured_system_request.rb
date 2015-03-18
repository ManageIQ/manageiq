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
    options[:src_configured_system_ids].length == 1 ? src_hosts.pluck(:hostname).first : "Multiple Hosts"
  end

  def src_hosts
    ConfiguredSystem.where(:id => options[:src_configured_system_ids])
  end

  private

  def default_description
    "Foreman install on [#{host_name}]"
  end
end
