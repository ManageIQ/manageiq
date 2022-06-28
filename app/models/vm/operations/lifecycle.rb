module Vm::Operations::Lifecycle
  extend ActiveSupport::Concern

  included do
    supports :retire do
      if orphaned?
        _("Retire not supported because VM is orphaned")
      elsif archived?
        _("Retire not supported because VM is archived")
      end
    end

    supports_not :publish

    api_relay_method :retire do |options|
      options
    end

    api_relay_method :retire_now, :retire
  end
end
