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

  delegate :corresponding_model, :to => :class
  alias_method :corresponding_vm_model, :corresponding_model

  def scan_via_ems?
    true
  end

  def self.supports_kickstart_provisioning?
    false
  end

  delegate :supports_kickstart_provisioning?, :to => :class

  def self.eligible_for_provisioning
    where(arel_table[:ems_id].not_eq(nil))
  end

  def active?
    false
  end

  def has_compliance_policies?
    _, plist = MiqPolicy.get_policies_for_target(self, "compliance", "miqtemplate_compliance_check")
    !plist.blank?
  end

end
