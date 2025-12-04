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
    case options[:removal_type]
    when "remove_from_disk"
      if vm.miq_provision || vm.is_tagged_with?("retire_full", :ns => "/managed/lifecycle")
        _log.info("#{log_prefix} Removing from disk...")
        vm.vm_destroy
      else
        _log.info("#{log_prefix} was not provisioned by us, not removing from disk")
      end
    when "unregister"
      _log.info("#{log_prefix} Unregistering...")
      vm.unregister
    else
      _log.error("#{log_prefix} Unknown retirement type [#{options[:removal_type]}]")
      return fail!("Unknown retirement type")
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
    "VM:<#{vm.name}> on Provider:<#{vm.ext_management_system&.name}>"
  end
end
