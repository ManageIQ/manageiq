class ServiceReconfigureRequest < MiqRequest
  TASK_DESCRIPTION  = 'Service Reconfigure'
  SOURCE_CLASS_NAME = 'Service'

  validates_inclusion_of :request_state, :in      => %w(pending finished) + ACTIVE_STATES,
                                         :message => "should be pending, #{ACTIVE_STATES.join(", ")} or finished"
  validate :must_have_user

  default_value_for(:source_id)    { |r| r.get_option(:src_id) }
  default_value_for :source_type,  SOURCE_CLASS_NAME

  def my_role
    'ems_operations'
  end

  def requested_task_idx
    [options[:src_id]]
  end
end
