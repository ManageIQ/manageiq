module Vm::Operations::Lifecycle
  extend ActiveSupport::Concern

  included do
    supports :retirement do
      if orphaned? || archived?
        unsupported_reason_add :retirement, "VM orphaned or archived already"
      end
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
