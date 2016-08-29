module ManageIQ::Providers::Redhat::InfraManager::Vm::Operations::Guest
  def validate_shutdown_guest
    return {:available => supports_vm_control_powered_on?, :message => unsupported_reason(:vm_control_powered_on)}
  end

  def raw_shutdown_guest
    with_provider_object(&:shutdown)
  rescue Ovirt::VmIsNotRunning
  end
end
