module Vm::Operations::Power

  include SupportsFeatureMixin
  extend ActiveSupport::Concern

  included do
    supports :start do
      unsupported_reason_add(:start, unsupported_reason(:vm_control_power_state)) unless supports_vm_control_power_state?(false)
    end

    supports :stop do
      unsupported_reason_add(:stop, unsupported_reason(:vm_control_power_state)) unless supports_vm_control_power_state?(true)
    end

    supports :suspend do
      unsupported_reason_add(:suspend, unsupported_reason(:vm_control_power_state)) unless supports_vm_control_power_state?(true)
    end

    supports :pause do
      unsupported_reason_add(:pause, unsupported_reason(:vm_control_power_state)) unless supports_vm_control_power_state?(true)
    end

    supports_not :shelve, :reason => _("shelve operation is not available for VM or Template.")
    supports_not :shelve_offload, :reason => _("Shelve Offload operation is not available for VM or Template.")
  end
end
