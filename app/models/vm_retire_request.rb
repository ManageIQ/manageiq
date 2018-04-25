class VmRetireRequest < MiqRetireRequest
  TASK_DESCRIPTION  = 'VM Retire'.freeze
  SOURCE_CLASS_NAME = 'Vm'.freeze
  ACTIVE_STATES     = %w(retired) + base_class::ACTIVE_STATES

  def my_zone
    vm = Vm.find_by(:id => options[:src_ids])
    vm.nil? ? super : vm.my_zone
  end
end
