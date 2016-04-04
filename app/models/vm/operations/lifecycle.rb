module Vm::Operations::Lifecycle
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
    {:available => !self.archived?, :message   => nil}
  end

  def validate_retire_now
    {:available => !(self.orphaned? || self.archived?), :message   => nil}
  end
end
