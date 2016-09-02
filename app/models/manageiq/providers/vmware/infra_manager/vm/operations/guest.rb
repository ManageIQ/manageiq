module ManageIQ::Providers::Vmware::InfraManager::Vm::Operations::Guest
  extend ActiveSupport::Concern

  included do
    supports :reboot_guest do
      unsupported_reason_add(:reboot_guest, unsupported_reason(:control)) unless supports_control?
      unsupported_reason_add(:reboot_guest, _("The VM is not powered on")) unless current_state == "on"
    end
  end

  def validate_shutdown_guest
    msg = validate_vm_control
    return {:available => msg[0], :message => msg[1]} unless msg.nil?
    return {:available => true, :message => ''} if tools_status && tools_status == 'toolsNotInstalled'
    return {:available => true, :message => nil} if current_state == 'on'
    {:available => false, :message => 'The VM is not powered on'}
  end

  def validate_standby_guest
    validate_vm_control_powered_on
  end

  def validate_reset
    validate_vm_control_powered_on
  end
end
