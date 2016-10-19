module Vm::Operations::Power
  extend ActiveSupport::Concern

  included do
    api_relay_method :start
    api_relay_method :stop
    api_relay_method :suspend
  end

  def validate_start
    validate_vm_control_not_powered_on
  end

  def validate_stop
    validate_vm_control_powered_on
  end

  def validate_suspend
    validate_vm_control_powered_on
  end

  def validate_pause
    validate_vm_control_powered_on
  end

  def validate_shelve
    validate_unsupported("Shelve Operation")
  end

  def validate_shelve_offload
    validate_unsupported("Shelve Offload Operation")
  end
end
