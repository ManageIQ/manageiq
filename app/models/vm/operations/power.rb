module Vm::Operations::Power
  extend ActiveSupport::Concern

  included do
    api_relay_method :start
    api_relay_method :stop
    api_relay_method :suspend

    supports :suspend do
      msg = unsupported_reason(:control) unless supports?(:control)
      msg ||= _('The VM is not powered on') unless vm_powered_on?
      unsupported_reason_add(:suspend, msg) if msg
    end

    supports :start do
      msg = unsupported_reason(:control) unless supports?(:control)
      msg ||= _('The VM is powered on') if vm_powered_on?
      unsupported_reason_add(:start, msg) if msg
    end

    supports :stop do
      msg = unsupported_reason(:control) unless supports?(:control)
      msg ||= _('The VM is not powered on') unless vm_powered_on?
      unsupported_reason_add(:stop, msg) if msg
    end
  end

  def vm_powered_on?
    current_state == 'on'
  end
end
