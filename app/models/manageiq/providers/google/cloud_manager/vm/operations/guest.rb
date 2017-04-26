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
    # Other providers update the power state, but we don't have a "reboot" state
  end
end
