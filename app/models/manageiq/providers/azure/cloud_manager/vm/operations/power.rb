module ManageIQ::Providers::Azure::CloudManager::Vm::Operations::Power
  extend ActiveSupport::Concern

  included do
    supports :reboot_guest do
      unsupported_reason_add(:reboot_guest, unsupported_reason(:control)) unless supports_control?
      unsupported_reason_add(:reboot_guest, _("The VM is not powered on")) unless current_state == "on"
    end
  end

  def raw_suspend
    provider_service.stop(name, resource_group)
    update_attributes!(:raw_power_state => "VM stopping")
  end

  def validate_pause
    validate_unsupported(_("Pause Operation"))
  end

  def raw_start
    provider_service.start(name, resource_group)
    update_attributes!(:raw_power_state => "VM starting")
  end

  def raw_stop
    provider_service.deallocate(name, resource_group)
    update_attributes!(:raw_power_state => "VM deallocating")
  end

  def raw_restart
    provider_service.restart(name, resource_group)
    update_attributes!(:raw_power_state => "VM starting")
  end

  def reboot_guest
    provider_service.restart(name, resource_group)
    update_attributes!(:raw_power_state => "VM starting")
  end
end
