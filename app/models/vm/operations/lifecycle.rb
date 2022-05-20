module Vm::Operations::Lifecycle
  extend ActiveSupport::Concern

  included do
    supports :retire do
      reason   = _("Retire not supported because VM is orphaned") if orphaned?
      reason ||= _("Retire not supported because VM is archived") if archived?
      unsupported_reason_add(:retire, reason) if reason
    end

    supports_not :publish

    api_relay_method :retire do |options|
      options
    end

    api_relay_method :retire_now, :retire
  end
end
