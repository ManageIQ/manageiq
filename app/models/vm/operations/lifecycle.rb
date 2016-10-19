module Vm::Operations::Lifecycle
  extend ActiveSupport::Concern

  included do
    supports :retire do
      unsupported_reason_add(:retire, "VM orphaned or archived already") if orphaned? || archived?
    end

    supports :migrate do
      if blank? || orphaned? || archived?
        unsupported_reason_add(:migrate, "Migrate operation in not supported.")
      end
    end

    api_relay_method :retire do |options|
      options
    end

    api_relay_method :retire_now, :retire
  end

  def validate_clone
    {:available => self.cloneable? && !(self.blank? || self.orphaned? || self.archived?), :message => nil}
  end

  def validate_publish
    {:available => !(self.blank? || self.orphaned? || self.archived?), :message   => nil}
  end
end
