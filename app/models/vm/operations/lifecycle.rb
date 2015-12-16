module Vm::Operations::Lifecycle
  def validate_clone
    {:available => self.cloneable? && !(self.blank? || self.orphaned? || self.archived?), :message => nil}
  end

  def validate_publish
    {:available => !(self.blank? || self.orphaned? || self.archived?) &&
                   MiqTemplate.where(:id => self.id).empty?,
     :message   => nil}
  end

  def validate_migrate
    {:available => !(self.blank? || self.orphaned? || self.archived?) &&
                   batch_operation_supported?('migrate', self.id) &&
                   MiqTemplate.where(:id => self.id).empty?,
     :message   => nil}
  end
end
