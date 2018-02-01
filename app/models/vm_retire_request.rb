class VmRetireRequest < MiqRequest
  TASK_DESCRIPTION  = 'VM Retire'.freeze
  SOURCE_CLASS_NAME = 'Vm'.freeze
  ACTIVE_STATES     = %w(retired) + base_class::ACTIVE_STATES

  validates :request_state, :inclusion => { :in => %w(pending finished) + ACTIVE_STATES, :message => "should be pending, #{ACTIVE_STATES.join(", ")} or finished" }
  validate :must_have_user

  def my_zone
    vm = Vm.find_by(:id => options[:src_ids])
    vm.nil? ? super : vm.my_zone
  end

  def my_role
    'ems_operations'
  end
end
