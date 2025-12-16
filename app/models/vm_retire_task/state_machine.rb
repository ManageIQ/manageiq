module VmRetireTask::StateMachine
  extend ActiveSupport::Concern

  def run_retire
    signal :check_vm_power_state
  end

  def check_vm_power_state
    if vm.power_state != "off"
      _log.info("#{log_prefix} is running, powering off...")
      vm.stop
      signal :poll_vm_stopped
    else
      _log.info("#{log_prefix} is stopped, retiring...")
      signal :start_retirement
    end
  end

  def poll_vm_stopped
    _log.info("#{log_prefix} has Power State:<#{vm.power_state}>")

    if vm.power_state != "off"
      _log.info("#{log_prefix} has not stopped")
      requeue_phase
    else
      _log.info("#{log_prefix} has stopped, retiring...")
      signal :start_retirement
    end
  end

  def remove_from_provider
    if options.fetch(:remove_from_provider_storage, true)
      _log.info("#{log_prefix} Removing from storage...")
      vm.vm_destroy
    else
      _log.info("#{log_prefix} Unregistering...")
      vm.unregister
    end

    signal :check_removed_from_provider
  end

  def check_removed_from_provider
    if vm.ext_management_system
      _log.info("#{log_prefix} not yet removed from provider...")
      vm.queue_refresh
      requeue_phase
    else
      _log.info("#{log_prefix} removed from provider...")
      signal :finish_retirement
    end
  end

  def log_prefix
    "VM:<#{vm.name}>"
  end
end
