module Vm::Operations::Power
  extend ActiveSupport::Concern

  included do
    api_relay_method :start
    api_relay_method :stop
    api_relay_method :suspend

    supports :suspend do
      if !vm_powered_on?
        _('The VM is not powered on')
      else
        unsupported_reason(:control)
      end
    end

    supports :start do
      if vm_powered_on?
        _('The VM is powered on')
      else
        unsupported_reason(:control)
      end
    end

    supports :stop do
      if !vm_powered_on?
        _('The VM is not powered on')
      else
        unsupported_reason(:control)
      end
    end
  end

  def vm_powered_on?
    current_state == 'on'
  end
end
