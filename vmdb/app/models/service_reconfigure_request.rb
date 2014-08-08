class ServiceReconfigureRequest < MiqRequest
  TASK_DESCRIPTION  = 'Service Reconfigure'
  SOURCE_CLASS_NAME = 'Service'
  REQUEST_TYPES     = %w(service_reconfigure)

  validates_inclusion_of :request_type,  :in      => REQUEST_TYPES,
                                         :message => "should be #{REQUEST_TYPES.join(", ")}"
  validates_inclusion_of :request_state, :in      => %w(pending finished) + ACTIVE_STATES,
                                         :message => "should be pending, #{ACTIVE_STATES.join(", ")} or finished"
  validate :must_have_user

  default_value_for :request_type, REQUEST_TYPES.first
  default_value_for :message,      "#{TASK_DESCRIPTION} - Request Created"
  default_value_for(:requester)    { |r| r.get_user }
  default_value_for(:source_id)    { |r| r.get_option(:src_id) }
  default_value_for :source_type,  SOURCE_CLASS_NAME

  def my_role
    'ems_operations'
  end

  def requested_task_idx
    [options[:src_id]]
  end
end
