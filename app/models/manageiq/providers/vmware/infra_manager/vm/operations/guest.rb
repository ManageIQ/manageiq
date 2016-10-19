module ManageIQ::Providers::Vmware::InfraManager::Vm::Operations::Guest
  extend ActiveSupport::Concern

  included do
    supports :reboot_guest do
      unsupported_reason_add(:reboot_guest, unsupported_reason(:control)) unless supports_control?
      unsupported_reason_add(:reboot_guest, _("The VM is not powered on")) unless current_state == "on"
    end

    supports :shutdown_guest do
      unsupported_reason_add(:shutdown_guest, unsupported_reason(:control)) unless supports_control?
      unless tools_status && tools_status == 'toolsNotInstalled'
        if current_state != "on"
          unsupported_reason_add(:shutdown_guest, _("The VM is not powered on"))
        end
      end
    end
  end

  def validate_standby_guest
    validate_vm_control_powered_on
  end

  def validate_reset
    validate_vm_control_powered_on
  end
end
