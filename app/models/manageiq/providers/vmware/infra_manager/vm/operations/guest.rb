module ManageIQ::Providers::Vmware::InfraManager::Vm::Operations::Guest
  extend ActiveSupport::Concern

  included do
    supports :reboot_guest do
      unsupported_reason_add(:reboot_guest, unsupported_reason(:control)) unless supports_control?
      unsupported_reason_add(:reboot_guest, _("The VM is not powered on")) unless current_state == "on"
    end

    supports :shutdown_guest do
      unsupported_reason_add(:shutdown_guest, unsupported_reason(:control)) unless supports_control?
      if current_state == "on"
        if tools_status == 'toolsNotInstalled'
          unsupported_reason_add(:shutdown_guest, _("The VM tools is not installed"))
        end
      else
        unsupported_reason_add(:shutdown_guest, _("The VM is not powered on"))
      end
    end

    supports :reset do
      unsupported_reason_add(:reset, unsupported_reason(:control)) unless supports_control?
      unsupported_reason_add(:reset, _("The VM is not powered on")) unless current_state == "on"
    end
  end

  def validate_standby_guest
    validate_vm_control_powered_on
  end
end
