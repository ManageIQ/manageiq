module Vm::Operations::Lifecycle
  extend ActiveSupport::Concern

  included do
    supports :retire do
      unsupported_reason_add(:retire, "VM orphaned or archived already") if orphaned? || archived?
    end
  end

  def validate_clone
    {:available => self.cloneable? && !(self.blank? || self.orphaned? || self.archived?), :message => nil}
  end

  def validate_publish
    {:available => !(self.blank? || self.orphaned? || self.archived?), :message   => nil}
  end

  def validate_migrate
    {:available => !(self.blank? || self.orphaned? || self.archived?), :message   => nil}
  end

  def validate_retire
    {:available => !(self.orphaned? || self.archived?), :message   => nil}
  end

  def validate_retire_now
    {:available => !(self.orphaned? || self.archived?), :message   => nil}
  end
end
