module ManageIQ::Providers::Redhat::InfraManager::Vm::Operations::Guest
  extend ActiveSupport::Concern

  included do
    supports :shutdown_guest do
      unsupported_reason_add(:shutdown_guest, unsupported_reason(:control)) unless supports_control?
      unsupported_reason_add(:shutdown_guest, _("The VM is not powered on")) unless current_state == "on"
    end

    supports :reboot_guest do
      unsupported_reason_add(:reboot_guest, unsupported_reason(:control)) unless supports_control?
      unsupported_reason_add(:reboot_guest, _("The VM is not powered on")) unless current_state == "on"
    end
  end

  def raw_shutdown_guest
    ext_management_system.ovirt_services.shutdown_guest(self)
  end

  def raw_reboot_guest
    ext_management_system.ovirt_services.reboot_guest(self)
  end
end
