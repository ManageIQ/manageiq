module Vm::Operations::Power
  extend ActiveSupport::Concern

  included do
    api_relay_method :start
    api_relay_method :stop
    api_relay_method :suspend

    supports :suspend do
      if !supports?(:control)
        unsupported_reason(:control)
      elsif !vm_powered_on?
        _('The VM is not powered on')
      end
    end

    supports :start do
      if !supports?(:control)
        unsupported_reason(:control)
      elsif vm_powered_on?
        _('The VM is powered on')
      end
    end

    supports :stop do
      if !supports?(:control)
        unsupported_reason(:control)
      elsif !vm_powered_on?
        _('The VM is not powered on')
      end
    end
  end

  def vm_powered_on?
    current_state == 'on'
  end
end
