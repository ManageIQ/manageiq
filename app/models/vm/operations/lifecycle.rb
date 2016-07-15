module Vm::Operations::Lifecycle

  extend ActiveSupport::Concern

  included do
    supports :retirement do
      if orphaned? || archived?
        unsupported_reason_add :retirement, "VM orphaned or archived already"
      end
    end

    supports :clone do
      unsupported_reason_add(:clone, _("Clone operation is not available for Vm or Template.")) unless
          self.cloneable? && !(self.blank? || self.orphaned? || self.archived?)
    end

    supports :migrate do
      unsupported_reason_add(:migrate, _("Migrate operation is not available for Vm or Template.")) unless
          !(self.blank? || self.orphaned? || self.archived?)
    end
  end

  def validate_publish
    {:available => !(self.blank? || self.orphaned? || self.archived?), :message   => nil}
  end

  def validate_retire
    {:available => !(self.orphaned? || self.archived?), :message   => nil}
  end

  def validate_retire_now
    {:available => !(self.orphaned? || self.archived?), :message   => nil}
  end
end
