class ServiceTemplateProvisionRequest < MiqRequest

  TASK_DESCRIPTION  = 'Service_Template_Provisioning'
  SOURCE_CLASS_NAME = 'ServiceTemplate'
  ACTIVE_STATES     = %w{ migrated } + self.base_class::ACTIVE_STATES

  validates_inclusion_of :request_state,  :in => %w{ pending finished } + ACTIVE_STATES, :message => "should be pending, #{ACTIVE_STATES.join(", ")} or finished"
  validate               :must_have_user

  default_value_for(:source_id)    { |r| r.get_option(:src_id) }
  default_value_for :source_type,  SOURCE_CLASS_NAME

  def my_role
    'ems_operations'
  end

  def my_zone
    nil
  end

  def requested_task_idx
    requested_count = 1
    (0..requested_count - 1).to_a
  end

  def customize_request_task_attributes(req_task_attrs, idx)
    req_task_attrs['options'][:pass] = idx
  end

  def self.create_request(values, requester_id, auto_approve=false)
    event_message = "#{TASK_DESCRIPTION} requested by <#{requester_id}>"
    super(values, requester_id, auto_approve, request_types.first, SOURCE_CLASS_NAME, event_message)
  end

  def self.update_request(request, values, requester_id)
    event_message = "#{TASK_DESCRIPTION} request was successfully updated by <#{requester_id}>"
    super(request, values, requester_id, SOURCE_CLASS_NAME, event_message)
  end
end
