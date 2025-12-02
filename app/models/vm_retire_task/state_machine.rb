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
end
