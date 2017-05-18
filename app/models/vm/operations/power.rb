module Vm::Operations::Power
  extend ActiveSupport::Concern

  included do
    api_relay_method :start
    api_relay_method :stop
    api_relay_method :suspend

    supports :suspend do
      msg = unsupported_reason(:control) unless supports_control?
      msg ||= _('The VM is not powered on') unless vm_powered_on?
      unsupported_reason_add(:suspend, msg) if msg
    end

    supports :start do
      msg = unsupported_reason(:control) unless supports_control?
      msg ||= _('The VM is powered on') if vm_powered_on?
      unsupported_reason_add(:start, msg) if msg
    end
  end

  def vm_powered_on?
    current_state == 'on'
  end

  def validate_stop
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
