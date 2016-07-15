module ManageIQ::Providers::Redhat::InfraManager::Vm::Operations::Guest

  include SupportsFeatureMixin
  extend ActiveSupport::Concern

  included do
    supports :shutdown_guest do
      unsupported_reason_add(:shutdown_guest, unsupported_reason(:vm_control_powered_on)) unless supports_vm_control_state?(true)
    end
  end

  def raw_shutdown_guest
    with_provider_object(&:shutdown)
  rescue Ovirt::VmIsNotRunning
  end
end
