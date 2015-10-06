class MiqTemplate < VmOrTemplate
  default_scope { where(:template => true) }

  include_concern 'Operations'

  def self.base_model
    MiqTemplate
  end

  def self.corresponding_model
    parent::Vm
  end
  class << self; alias_method :corresponding_vm_model, :corresponding_model; end

  def corresponding_model
    self.class.corresponding_model
  end
  alias_method :corresponding_vm_model, :corresponding_model

  def scan_via_ems?
    true
  end

  def self.supports_kickstart_provisioning?
    false
  end

  def supports_kickstart_provisioning?
    self.class.supports_kickstart_provisioning?
  end

  def self.eligible_for_provisioning
    where(arel_table[:ems_id].not_eq(nil))
  end

  def active?; false; end
end
