class VmMigrateRequest < MiqRequest
  TASK_DESCRIPTION  = 'VM Migrate'
  SOURCE_CLASS_NAME = 'Vm'
  ACTIVE_STATES     = %w( migrated ) + base_class::ACTIVE_STATES

  validates_inclusion_of :request_state,  :in => %w( pending finished ) + ACTIVE_STATES, :message => "should be pending, #{ACTIVE_STATES.join(", ")} or finished"
  validate               :must_have_user
  include MiqProvisionQuotaMixin

  def vm
    @vm ||= Vm.find_by(:id => options[:src_ids])
  end

  def my_zone
    vm.nil? ? super : vm.my_zone
  end

  def my_role(_action = nil)
    'ems_operations'
  end

  def my_queue_name
    vm.nil? ? super : vm.queue_name_for_ems_operations
  end
end
