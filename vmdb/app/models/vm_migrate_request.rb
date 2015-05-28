class VmMigrateRequest < MiqRequest

  TASK_DESCRIPTION  = 'VM Migrate'
  SOURCE_CLASS_NAME = 'VmOrTemplate'
  ACTIVE_STATES     = %w{ migrated } + self.base_class::ACTIVE_STATES

  validates_inclusion_of :request_state,  :in => %w{ pending finished } + ACTIVE_STATES, :message => "should be pending, #{ACTIVE_STATES.join(", ")} or finished"
  validate               :must_have_user

  default_value_for(:request_type) { |r| r.request_types.first }
  default_value_for :message,      "#{TASK_DESCRIPTION} - Request Created"
  default_value_for(:requester)    { |r| r.get_user }

  def my_zone
    vm = Vm.where(:id => options[:src_ids]).first
    vm.nil? ? super : vm.my_zone
  end

  def my_role
    'ems_operations'
  end
end
