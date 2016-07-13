module ManageIQ::Providers::Vmware::InfraManager::Vm::Operations::Guest

  include SupportsFeatureMixin
  extend ActiveSupport::Concern

  included do
    supports :shutdown_guest do
      unsupported_reason_add(:shutdown_guest, unsupported_reason(:control)) unless supports_control?
      unsupported_reason_add(:shutdown_guest, "Tools not installed") if tools_status == 'toolsNotInstalled'
      unsupported_reason_add(:shutdown_guest, "The VM is not powered on") if current_state != 'on'
    end

    supports :standby_guest do
      unsupported_reason_add(:standby_guest, unsupported_reason(:vm_control_power_state)) unless supports_vm_control_power_state?(true)
    end

    supports :reboot_guest do
      unsupported_reason_add(:reboot_guest, unsupported_reason(:vm_control_power_state)) unless supports_vm_control_power_state?(true)
    end

    supports :reset do
      unsupported_reason_add(:reset, unsupported_reason(:vm_control_power_state)) unless supports_vm_control_power_state?(true)
    end
  end
end
