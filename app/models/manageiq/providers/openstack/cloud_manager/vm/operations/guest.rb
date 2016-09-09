module ManageIQ::Providers::Openstack::CloudManager::Vm::Operations::Guest
  extend ActiveSupport::Concern

  included do
    supports :reboot_guest do
      unsupported_reason_add(:reboot_guest, unsupported_reason(:control)) unless supports_control?
      unsupported_reason_add(:reboot_guest, _("The VM is not powered on")) unless current_state == "on"
    end

    supports :reset do
      unsupported_reason_add(:reset, unsupported_reason(:control)) unless supports_control?
      unsupported_reason_add(:reset, _("The VM is not powered on")) unless current_state == "on"
    end
  end

  def raw_reboot_guest
    with_provider_object(&:reboot)
    # Temporarily update state for quick UI response until refresh comes along
    self.update_attributes!(:raw_power_state => "REBOOT")
  end

  def raw_reset
    with_provider_object { |instance| instance.reboot("HARD") }
    # Temporarily update state for quick UI response until refresh comes along
    self.update_attributes!(:raw_power_state => "HARD_REBOOT")
  end
end
