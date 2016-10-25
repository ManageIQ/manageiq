module Vm::Operations::Power
  extend ActiveSupport::Concern

  included do
    api_relay_method :start
    api_relay_method :stop
    api_relay_method :suspend

    supports :suspend do
      msg = supports_control_powered_on
      unsupported_reason_add(:suspend, msg) if msg
    end

    supports :pause do
      msg = supports_control_powered_on
      unsupported_reason_add(:pause, msg) if msg
    end
  end

  def supports_control_powered_on
    msg = supports_control_message
    msg || powered_on_message
  end

  def supports_control_message
    unsupported_reason(:control) unless supports_control?
  end

  def powered_on_message
    _('The VM is not powered on') unless vm_powered_on?
  end

  def vm_powered_on?
    current_state == 'on'
  end

  def validate_start
    validate_vm_control_not_powered_on
  end

  def validate_stop
    validate_vm_control_powered_on
  end

  def validate_shelve
    validate_unsupported("Shelve Operation")
  end

  def validate_shelve_offload
    validate_unsupported("Shelve Offload Operation")
  end
end
