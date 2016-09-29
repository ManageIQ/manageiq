module ManageIQ::Providers::Google::CloudManager::Vm::Operations::Guest
  extend ActiveSupport::Concern

  included do
    supports :reboot_guest do
      unsupported_reason_add(:reboot_guest, unsupported_reason(:control)) unless supports_control?
      unsupported_reason_add(:reboot_guest, _("The VM is not powered on")) unless current_state == "on"
    end
  end

  def raw_reboot_guest
    with_provider_object(&:reboot)
    self.update_attributes!(:raw_power_state => "reboot") # show state as suspended
  end
end
