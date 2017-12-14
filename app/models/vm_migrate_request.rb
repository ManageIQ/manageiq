class VmMigrateRequest < MiqRequest
  TASK_DESCRIPTION  = 'VM Migrate'
  SOURCE_CLASS_NAME = 'Vm'
  ACTIVE_STATES     = %w( migrated ) + base_class::ACTIVE_STATES

  validates_inclusion_of :request_state,  :in => %w( pending finished ) + ACTIVE_STATES, :message => "should be pending, #{ACTIVE_STATES.join(", ")} or finished"
  validate               :must_have_user
  include MiqProvisionQuotaMixin

  def my_zone
    vm = Vm.find_by(:id => options[:src_ids])
    vm.nil? ? super : vm.my_zone
  end

  def my_role
    'ems_operations'
  end
end
