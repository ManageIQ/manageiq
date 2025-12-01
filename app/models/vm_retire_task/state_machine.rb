module VmRetireTask::StateMachine
  extend ActiveSupport::Concern

  def run_retire
    signal :check_vm_power_state
  end

  def check_vm_power_state
    if vm.power_state != "off"
      _log.info("Powering Off VM <#{vm.name}> in provider <#{vm.ext_management_system&.name}>")
      vm.stop
      signal :poll_vm_stopped
    else
      _log.info("VM <#{vm.name}> stopped, retiring...")
      signal :start_retirement
    end
  end

  def poll_vm_stopped
    _log.info("VM:<#{vm.name}> on Provider:<#{vm.ext_management_system&.name}> has Power State:<#{vm.power_state}>")

    if vm.power_state != "off"
      _log.info("VM:<#{vm.name}> on Provider:<#{vm.ext_management_system&.name}> has not stopped")
      requeue_phase
    else
      _log.info("VM:<#{vm.name}> on Provider:<#{vm.ext_management_system&.name}> has stopped, retiring...")
      signal :start_retirement
    end
  end

  def start_retirement
    Notification.create!(:type => :vm_retiring, :subject => vm)
    vm.start_retirement
    signal :finish_retirement
  end

  def finish_retirement
    vm.finish_retirement
    Notification.create!(:type => :vm_retired, :subject => vm)
    signal :finish
  end

  def finish
    mark_execution_servers
    update_and_notify_parent(:state => 'finished')
  end
end
