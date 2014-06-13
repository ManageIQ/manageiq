class VmMigrateRequest < MiqRequest

  TASK_DESCRIPTION  = 'VM Migrate'
  SOURCE_CLASS_NAME = 'VmOrTemplate'
  REQUEST_TYPES     = %w{ vm_migrate }
  ACTIVE_STATES     = %w{ migrated } + self.base_class::ACTIVE_STATES

  validates_inclusion_of :request_type,   :in => REQUEST_TYPES,                          :message => "should be #{REQUEST_TYPES.join(", ")}"
  validates_inclusion_of :request_state,  :in => %w{ pending finished } + ACTIVE_STATES, :message => "should be pending, #{ACTIVE_STATES.join(", ")} or finished"
  validate               :must_have_user

  default_value_for :request_type, REQUEST_TYPES.first
  default_value_for :message,      "#{TASK_DESCRIPTION} - Request Created"
  default_value_for(:requester)    { |r| r.get_user }

  def my_role
    'ems_operations'
  end

end
