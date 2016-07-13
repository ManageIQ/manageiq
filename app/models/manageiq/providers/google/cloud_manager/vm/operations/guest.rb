module ManageIQ::Providers::Google::CloudManager::Vm::Operations::Guest

  include SupportsFeatureMixin
  extend ActiveSupport::Concern

  included do
    supports :reboot_guest do
      unsupported_reason_add(:reboot_guest, unsupported_reason(:vm_control_power_state)) unless supports_vm_control_power_state?(true)
    end
  end

  def raw_reboot_guest
    with_provider_object(&:reboot)
    self.update_attributes!(:raw_power_state => "reboot") # show state as suspended
  end
end
