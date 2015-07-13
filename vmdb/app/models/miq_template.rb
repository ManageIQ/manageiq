class MiqTemplate < VmOrTemplate
  default_scope { where(:template => true) }

  include_concern 'Operations'

  def self.base_model
    MiqTemplate
  end

  def self.model_suffix
    if parent == Object
      self == MiqTemplate ? "" : self.name[8..-1]
    elsif parent.parent == ManageIQ::Providers
      parent.name.demodulize.sub(/Manager$/, '')
    else
      parent.parent.name.demodulize
    end
  end

  def self.corresponding_model
    if parent == Object
      @corresponding_model ||= "Vm#{self.model_suffix}".constantize
    else
      parent::Vm
    end
  end
  class << self; alias corresponding_vm_model corresponding_model; end

  def corresponding_model
    self.class.corresponding_model
  end
  alias corresponding_vm_model corresponding_model

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
    where(self.arel_table[:ems_id].not_eq(nil))
  end

  def active?; false; end
end
